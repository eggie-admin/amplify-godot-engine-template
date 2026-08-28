extends CanvasLayer

const OLLAMA_BASE := "http://127.0.0.1:11434"
const OLLAMA_MODEL := "qwen3:0.6b"
const OPENAI_URL := "https://api.openai.com/v1/responses"
const OPENAI_MODEL := "gpt-5.6"

# Base64-encoded JSON session manifest emitted by ci_preflight.py at build time.
# Decode with Marshalls.base64_to_raw() + bytes_to_var() or JSON.parse_string().
const SESSION_MANIFEST_B64 := "eyJwcm9qZWN0IjoiS0FJIDkwMDAgU2FuY3R1YXJ5IC8gTHVtIiwicGFja2FnZSI6ImNvbS5lZ2dpZS5rYWk5MDAwc2FuY3R1YXJ5IiwiYXJjaCI6ImFybTY0LXY4YSIsInZlcnNpb25fbmFtZSI6IjAuMy4wLXNtLXg0MDAiLCJ2ZXJzaW9uX2NvZGUiOiIzIiwib3JpZW50YXRpb24iOiJsYW5kc2NhcGUiLCJyZW5kZXJlciI6ImdsX2NvbXBhdGliaWxpdHkiLCJvcGVuYWlfbW9kZWwiOiJncHQtNS42Iiwib2xsYW1hX21vZGVsIjoicXdlbjM6MC42YiIsIm9sbGFtYV9lbmRwb2ludCI6Imh0dHA6Ly8xMjcuMC4wLjE6MTE0MzQiLCJhdXRob3JpdHkiOiJodW1hbi1maW5hbCIsImF1dG9fcHVibGlzaCI6ZmFsc2V9"

var body: VBoxContainer
var status_strip: Label
var output: RichTextLabel
var prompt: LineEdit
var ollama_health: HTTPRequest
var ollama_chat: HTTPRequest
var openai_chat: HTTPRequest
var provider := "OLLAMA"
var ollama_online := false
var openai_key := ""
var _lum_instructions := "You are Lum inside KAI 9000. Human operator has final authority. Never auto-publish. Be concise and practical."

func _ready() -> void:
	layer = 10
	_load_manifest()
	_build_requests()
	_build_shell()
	_show_chat()
	_check_ollama()

func _load_manifest() -> void:
	var raw := Marshalls.base64_to_raw(SESSION_MANIFEST_B64)
	if raw.is_empty():
		return
	var manifest = JSON.parse_string(raw.get_string_from_utf8())
	if not (manifest is Dictionary):
		return
	var project: String = manifest.get("project", "KAI 9000 Sanctuary / Lum")
	var arch: String = manifest.get("arch", "arm64-v8a")
	var version: String = manifest.get("version_name", "")
	var orientation: String = manifest.get("orientation", "landscape")
	var renderer: String = manifest.get("renderer", "gl_compatibility")
	var authority: String = manifest.get("authority", "human-final")
	_lum_instructions = (
		"You are Lum, the AI executive assistant inside %s. "
		"Runtime: Godot 4 / Android / %s / %s / orientation=%s / renderer=%s. "
		"Version: %s. Authority model: %s. "
		"Never auto-publish, never store API keys, be concise and practical. "
		"The human operator has final authority on all decisions."
	) % [project, arch, "Samsung SM-X400", orientation, renderer, version, authority]

func _build_requests() -> void:
	ollama_health = HTTPRequest.new()
	ollama_health.timeout = 4.0
	ollama_health.request_completed.connect(_on_ollama_health)
	add_child(ollama_health)
	ollama_chat = HTTPRequest.new()
	ollama_chat.timeout = 90.0
	ollama_chat.request_completed.connect(_on_ollama_chat)
	add_child(ollama_chat)
	openai_chat = HTTPRequest.new()
	openai_chat.timeout = 90.0
	openai_chat.request_completed.connect(_on_openai_chat)
	add_child(openai_chat)

func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var top := PanelContainer.new()
	top.custom_minimum_size = Vector2(0, 132)
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 6)
	top.add_child(top_box)
	var title := Label.new()
	title.text = "KAI 9000  //  LUM COCKPIT"
	title.add_theme_font_size_override("font_size", 28)
	top_box.add_child(title)
	status_strip = Label.new()
	status_strip.add_theme_font_size_override("font_size", 16)
	top_box.add_child(status_strip)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	top_box.add_child(nav)
	for name in ["CHAT", "TOOLS", "CMS", "STATUS"]:
		var b := Button.new()
		b.text = name
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(name))
		nav.add_child(b)
	var viewport_gap := Control.new()
	viewport_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(viewport_gap)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 600)
	root.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	_update_status_strip()

func _clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _select_tab(name: String) -> void:
	match name:
		"CHAT": _show_chat()
		"TOOLS": _show_tools()
		"CMS": _show_cms()
		"STATUS": _show_status()

func _heading(text: String) -> Label:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 22)
	return h

func _show_chat() -> void:
	_clear_body()
	body.add_child(_heading("CHAT WITH LUM  //  ROUTE: " + provider))
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.custom_minimum_size = Vector2(0, 300)
	output.text = "[b]Lum:[/b] Cockpit online. Local boss is Ollama. OpenAI is optional and session-only."
	body.add_child(output)
	prompt = LineEdit.new()
	prompt.placeholder_text = "Speak to Lum..."
	prompt.text_submitted.connect(_submit_chat)
	body.add_child(prompt)
	var row := HBoxContainer.new()
	body.add_child(row)
	var send := Button.new()
	send.text = "TALK TO LUM"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.pressed.connect(_send_prompt)
	row.add_child(send)
	var route := Button.new()
	route.text = "SWITCH AI"
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.pressed.connect(_toggle_provider)
	row.add_child(route)

func _show_tools() -> void:
	_clear_body()
	body.add_child(_heading("KAI TOOL CONSOLE"))
	var check := Button.new()
	check.text = "CHECK OLLAMA NOW"
	check.pressed.connect(_check_ollama)
	body.add_child(check)
	var reset := Button.new()
	reset.text = "RESET 3D LUM CAMERA"
	reset.pressed.connect(_reset_camera)
	body.add_child(reset)
	var local := Button.new()
	local.text = "ROUTE LUM TO LOCAL OLLAMA"
	local.pressed.connect(_set_provider.bind("OLLAMA"))
	body.add_child(local)
	var cloud := Button.new()
	cloud.text = "ROUTE LUM TO OPENAI"
	cloud.pressed.connect(_set_provider.bind("OPENAI"))
	body.add_child(cloud)
	var note := Label.new()
	note.text = "Operator-triggered tools only. Auto-publish and autonomous mutation are OFF."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

func _show_cms() -> void:
	_clear_body()
	body.add_child(_heading("IN-APP CMS / SESSION CONFIG"))
	var note := Label.new()
	note.text = "Secrets remain transient. This panel never writes the OpenAI key to disk."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var key_field := LineEdit.new()
	key_field.secret = true
	key_field.placeholder_text = "OpenAI API key for this session (optional)"
	key_field.text = openai_key
	key_field.text_changed.connect(_on_key_changed)
	body.add_child(key_field)
	var editor := TextEdit.new()
	editor.custom_minimum_size = Vector2(0, 270)
	editor.text = "{\n  \"lum_name\": \"Lum\",\n  \"local_model\": \"qwen3:0.6b\",\n  \"openai_model\": \"gpt-5.6\",\n  \"authority\": \"human-final\",\n  \"auto_publish\": false\n}"
	body.add_child(editor)

func _show_status() -> void:
	_clear_body()
	body.add_child(_heading("SYSTEM STATUS"))
	var status := RichTextLabel.new()
	status.bbcode_enabled = true
	status.custom_minimum_size = Vector2(0, 380)
	status.text = "[b]3D Lum viewport[/b]  ● READY\n[b]Godot 4 runtime[/b]  ● READY\n[b]Ollama localhost[/b]  %s\n[b]OpenAI Lum route[/b]  %s\n[b]CMS/session config[/b]  ● READY\n[b]Tools[/b]  ● READY\n[b]Auto-publish[/b]  ● OFF\n[b]Embedded API keys[/b]  ● NONE" % ["● ONLINE" if ollama_online else "● OFFLINE", "● READY" if not openai_key.is_empty() else "● KEY REQUIRED"]
	body.add_child(status)
	var refresh := Button.new()
	refresh.text = "REFRESH STATUS"
	refresh.pressed.connect(_check_ollama)
	body.add_child(refresh)

func _toggle_provider() -> void:
	provider = "OPENAI" if provider == "OLLAMA" else "OLLAMA"
	_update_status_strip()
	_show_chat()

func _set_provider(next: String) -> void:
	provider = next
	_update_status_strip()
	_show_tools()

func _submit_chat(text: String) -> void:
	var clean := text.strip_edges()
	if not clean.is_empty(): _send_text(clean)

func _send_prompt() -> void:
	if not is_instance_valid(prompt): return
	var clean := prompt.text.strip_edges()
	if not clean.is_empty(): _send_text(clean)

func _send_text(text: String) -> void:
	if is_instance_valid(output): output.text = "[b]You:[/b] %s\n\n[b]Lum:[/b] thinking..." % text
	if provider == "OPENAI": _send_openai(text)
	else: _send_ollama(text)

func _send_ollama(text: String) -> void:
	var payload := JSON.stringify({"model": OLLAMA_MODEL, "stream": false, "messages": [{"role": "system", "content": "You are Lum inside KAI 9000. The human operator has final authority. Never auto-publish. Be concise and practical."}, {"role": "user", "content": text}]})
	var err := ollama_chat.request(OLLAMA_BASE + "/api/chat", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK and is_instance_valid(output): output.text = "[b]Lum:[/b] Local Ollama request could not start."

func _send_openai(text: String) -> void:
	if openai_key.is_empty():
		if is_instance_valid(output): output.text = "[b]Lum:[/b] Load an OpenAI API key in CMS for this session, or switch back to Ollama."
		return
	var payload := JSON.stringify({"model": OPENAI_MODEL, "instructions": _lum_instructions, "input": text})
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + openai_key]
	var err := openai_chat.request(OPENAI_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK and is_instance_valid(output): output.text = "[b]Lum:[/b] OpenAI request could not start."

func _check_ollama() -> void:
	status_strip.text = "LUM: ONLINE  |  OLLAMA: CHECKING  |  OPENAI: %s" % ("READY" if not openai_key.is_empty() else "KEY NOT LOADED")
	ollama_health.request(OLLAMA_BASE + "/api/tags")

func _on_ollama_health(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	ollama_online = response_code >= 200 and response_code < 300
	_update_status_strip()

func _on_ollama_chat(_result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	if not is_instance_valid(output): return
	if response_code < 200 or response_code >= 300:
		output.text = "[b]Lum:[/b] Ollama returned HTTP %d." % response_code
		return
	var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("message") and parsed["message"] is Dictionary:
		output.text = "[b]Lum:[/b] " + str(parsed["message"].get("content", "No response text."))
	else: output.text = "[b]Lum:[/b] Ollama response could not be parsed."

func _on_openai_chat(_result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	if not is_instance_valid(output): return
	if response_code < 200 or response_code >= 300:
		output.text = "[b]Lum:[/b] OpenAI returned HTTP %d." % response_code
		return
	var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		output.text = "[b]Lum:[/b] OpenAI response could not be parsed."
		return
	var pieces: Array[String] = []
	for item in parsed.get("output", []):
		if item is Dictionary:
			for content in item.get("content", []):
				if content is Dictionary and content.get("type", "") == "output_text": pieces.append(str(content.get("text", "")))
	output.text = "[b]Lum:[/b] " + ("\n".join(pieces) if not pieces.is_empty() else "OpenAI returned no text output.")

func _on_key_changed(value: String) -> void:
	openai_key = value.strip_edges()
	_update_status_strip()

func _update_status_strip() -> void:
	if not is_instance_valid(status_strip): return
	status_strip.text = "LUM: ONLINE  |  OLLAMA: %s  |  OPENAI: %s  |  ROUTE: %s" % ["ONLINE" if ollama_online else "OFFLINE", "READY" if not openai_key.is_empty() else "KEY NOT LOADED", provider]

func _reset_camera() -> void:
	var sanctuary := get_parent()
	if sanctuary == null: return
	sanctuary.set("yaw", 0.0)
	sanctuary.set("pitch", -0.08)
	sanctuary.set("distance", 4.2)
