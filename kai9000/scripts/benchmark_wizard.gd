extends CanvasLayer

const SETTINGS_PATH := "user://kai_video_audio_profile.json"

var panel: PanelContainer
var report: RichTextLabel
var run_button: Button
var profile_option: OptionButton
var toggle_button: Button
var last_average_fps := 0.0
var recommended_profile := "balanced"


func _ready() -> void:
	_build_ui()
	panel.visible = not FileAccess.file_exists(SETTINGS_PATH)
	_refresh_report("Ready. Run the benchmark on the actual device.")


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	toggle_button = Button.new()
	toggle_button.text = "GPU / AUDIO"
	toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle_button.position = Vector2(-190.0, 22.0)
	toggle_button.size = Vector2(168.0, 52.0)
	toggle_button.pressed.connect(_toggle_panel)
	root.add_child(toggle_button)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-420.0, -430.0)
	panel.size = Vector2(840.0, 860.0)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "KAI 9000 // DEVICE BENCHMARK"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var note := Label.new()
	note.text = "Reports the renderer Godot actually selected. Vulkan is preferred; OpenGL fallback stays allowed."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

	report = RichTextLabel.new()
	report.bbcode_enabled = true
	report.custom_minimum_size = Vector2(0.0, 440.0)
	report.fit_content = false
	box.add_child(report)

	run_button = Button.new()
	run_button.text = "RUN 2 SECOND BENCHMARK"
	run_button.pressed.connect(_run_benchmark)
	box.add_child(run_button)

	profile_option = OptionButton.new()
	profile_option.add_item("Performance", 0)
	profile_option.add_item("Balanced", 1)
	profile_option.add_item("Quality", 2)
	box.add_child(profile_option)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var save_button := Button.new()
	save_button.text = "SAVE PROFILE"
	save_button.pressed.connect(_save_profile)
	buttons.add_child(save_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(_toggle_panel)
	buttons.add_child(close_button)


func _toggle_panel() -> void:
	panel.visible = not panel.visible


func _run_benchmark() -> void:
	if run_button.disabled:
		return
	run_button.disabled = true
	_refresh_report("Sampling frame rate...")

	var total := 0.0
	var samples := 0
	for _i in range(120):
		await get_tree().process_frame
		var fps := float(Engine.get_frames_per_second())
		if fps > 0.0:
			total += fps
			samples += 1

	last_average_fps = total / max(samples, 1)
	var driver := RenderingServer.get_current_rendering_driver_name()
	if driver.begins_with("opengl"):
		recommended_profile = "performance"
	elif last_average_fps >= 55.0:
		recommended_profile = "quality"
	elif last_average_fps >= 40.0:
		recommended_profile = "balanced"
	else:
		recommended_profile = "performance"

	_select_profile(recommended_profile)
	_refresh_report("Benchmark complete.")
	run_button.disabled = false


func _select_profile(profile: String) -> void:
	match profile:
		"performance": profile_option.select(0)
		"quality": profile_option.select(2)
		_: profile_option.select(1)


func _profile_name() -> String:
	match profile_option.selected:
		0: return "performance"
		2: return "quality"
		_: return "balanced"


func _save_profile() -> void:
	var profile := _profile_name()
	match profile:
		"performance": Engine.max_fps = 45
		"balanced": Engine.max_fps = 60
		"quality": Engine.max_fps = 0

	var payload := {
		"profile": profile,
		"average_fps": last_average_fps,
		"renderer": RenderingServer.get_current_rendering_method(),
		"render_driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"audio_driver": AudioServer.get_driver_name(),
		"audio_mix_rate": AudioServer.get_mix_rate(),
		"audio_latency_seconds": AudioServer.get_output_latency(),
		"saved_unix": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "  "))
	_refresh_report("Saved profile: " + profile)


func _refresh_report(status: String) -> void:
	if report == null:
		return
	var renderer := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var gpu := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var audio := AudioServer.get_driver_name()
	var mix_rate := AudioServer.get_mix_rate()
	var latency_ms := AudioServer.get_output_latency() * 1000.0
	var fps_text := "not sampled" if last_average_fps <= 0.0 else "%.1f" % last_average_fps
	report.text = (
		"[b]STATUS[/b]  " + status + "\n\n" +
		"[b]Renderer[/b]  " + renderer + "\n" +
		"[b]Driver[/b]    " + driver + "\n" +
		"[b]GPU[/b]       " + gpu + "\n" +
		"[b]Vendor[/b]    " + vendor + "\n" +
		"[b]FPS avg[/b]   " + fps_text + "\n\n" +
		"[b]Audio[/b]     " + audio + "\n" +
		"[b]Mix rate[/b]  %.0f Hz\n" % mix_rate +
		"[b]Latency[/b]   %.1f ms\n\n" % latency_ms +
		"[b]Recommendation[/b]  " + recommended_profile.to_upper()
	)
