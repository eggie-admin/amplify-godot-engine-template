extends CanvasLayer

const OLLAMA_BASE := "http://127.0.0.1:11434"
const OLLAMA_MODEL := "qwen3:0.6b"
const OPENAI_URL := "https://api.openai.com/v1/responses"
const OPENAI_MODEL := "gpt-5.6"

var panel: PanelContainer
var body: VBoxContainer
var status_strip: Label
var provider_label: Label
var output: RichTextLabel
var prompt: LineEdit
var api_key: LineEdit
var cms_editor: TextEdit
var ollama_health: HTTPRequest
var ollama_chat: HTTPRequest
var openai_chat: HTTPRequest
var active_tab := "CHAT"
var provider := "OLLAMA"
var ollama_online := false
var openai_configured := false

func _ready() -> void:
	_build_requests()
	_build_shell()
	_show_chat()
	_check_ollama()

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
	status_strip.text = "LUM: ONLINE  |  OLLAMA: CHECKING  |  OPENAI: KEY NOT LOADED"
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

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 600)
	root.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)

func _clear_body() -> void:
	for child in body.get_children():
		child.queue_free()

func _select_tab(name: String) -> void:
	active_tab = name
	match name:
		"CHAT": _show_chat()
		"TOOLS": _show_tools()
		"CMS": _show_cms()
		"STATUS": _show_status()

func _show_chat() -> void:
	_clear_body()
	provider_label = Label.new()
	provider_label.text = "LUM ROUTE: %s" % provider
	provider_label.add_theme_font_size_override("font_size", 18)
	body.add_child(provider_label)
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.fit_content = false
	output.custom_minimum_size = Vector2(0, 300)
	output.text = "[b]Lum:[/b] Cockpit online. Local boss is Ollama; OpenAI is available when you load a key for this session."
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
	var h := Label.new()
	h.text = "KAI TOOL CONSOLE"
	h.add_theme_font_size_override("font_size", 22)
	body.add_child(h)
	var check := Button.new()
	check.text = "CHECK OLLAMA NOW"
	check.pressed.connect(_check_ollama)
	body.add_child(check)
	var rotate := Button.new()
	rotate.text = "RESET 3D LUM CAMERA"
	rotate.pressed.connect(_reset_camera)
	body.add_child(rotate)
	var local := Button.new()
	local.text = "ROUTE LUM TO LOCAL OLLAMA"
	local.pressed.connect(_set_provider.bind("OLLAMA"))
	body.add_child(local)
	var cloud := Button.new()
	cloud.text = "ROUTE LUM TO OPENAI"
	cloud.pressed.connect(_set_provider.bind("OPENAI"))
	body.add_child(cloud)
	var note := Label.new()
	note.text = "Tools are Professor-triggered only. No autonomous publish or mutation actions are enabled."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

func _show_cms() -> void:
	_clear_body()
	var h := Label.new()
	h.text = "IN-APP CMS / RUNTIME CONFIG"
	h.add_theme_font_size_override("font_size", 22)
	body.add_child(h)
	var note := Label.new()
	note.text = "This release keeps secrets transient. Nothing typed below is written to disk."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	api_key = LineEdit.new()
	api_key.secret = true
	api_key.placeholder_text = "OpenAI API key for this session (optional)"
	api_key.text_changed.connect(_on_key_changed)
	body.add_child(api_key)
	cms_editor = TextEdit.new()
	cms_editor.custom_minimum_size = Vector2(0, 270)
	cms_editor.text = "{\n  \"lum_name\": \"Lum\",\n  \"local_model\": \"qwen3:0.6b\",\n  \"openai_model\": \"gpt-5.6\",\n  \"authority\": \"human-final\",\n  \"auto_publish\": false\n}"
	body.add_child(cms_editor)
	var apply := Button.new()
	apply.text = "APPLY SESSION CONFIG"
	apply.pressed.connect(_apply_cms)
	body.add_child(apply)

func _show_status() -> void:
	_clear_body()
	var h := Label.new()
	h.text = "SYSTEM STATUS"
	h.add_theme_font_size_override("font_size", 22)
	body.add_child(h)
	var status := RichTextLabel.new()
	status.bbcode_enabled = true
	status.custom_minimum_size = Vector2(0, 360)
	status.text = "[b]Lum 3D runtime[/b]  ● READY\n[b]Godot 4 cockpit[/b]  ● READY\n[b]Ollama localhost[/b]  %s\n[b]OpenAI Lum route[/b]  %s\n[b]CMS/runtime config[/b]  ● READY\n[b]Tools[/b]  ● READY\n[b]Auto-publish[/b]  ● OFF\n[b]Embedded API keys[/b]  ● NONE" % ["● ONLINE" if ollama_online else "● OFFLINE", "● READY" if openai_configured else "● KEY REQUIRED"]
	body.add_child(status)
	var refresh := Button.new()
	refresh.text = "REFRESH STATUS"
	refresh.pressed.connect(_refresh_status)
	body.add_child(refresh)

func _toggle_provider() -> void:
	provider = "OPENAI" if provider == "OLLAMA" else "OLLAMA"
	_show_chat()

func _set_provider(next: String) -> void:
	provider = next
	_show_tools()
	_update_status_strip()

func _submit_chat(text: String) -> void:
	if text.strip_edges().is_empty(): return
	_send_text(text.strip_edges())

func _send_prompt() -> void:
	if prompt == null: return
	var text := prompt.text.strip_edges()
	if text.is_empty(): return
	_send_text(text)

func _send_text(text: String) -> void:
	if output != null:
		output.text = "[b]You:[/b] %s\n\n[b]Lum:[/b] thinking..." % text
	if provider == "OPENAI":
		_send_openai(text)
	else:
		_send_ollama(text)

func _send_ollama(text: String) -> void:
	var payload := JSON.stringify({
		"model": OLLAMA_MODEL,
		"stream": false,
		"messages": [
			{"role": "system", "content": "You are Lum, the KAI 9000 assistant. The human operator has final authority. Be concise, practical, and never auto-publish."},
			{"role": "user", "content": text}
		]
	})
	var err := ollama_chat.request(OLLAMA_BASE + "/api/chat", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK and output != null:
		output.text = "[b]Lum:[/b] Local Ollama request could not start."

func _send_openai(text: String) -> void:
	if api_key == null or api_key.text.strip_edges().is_empty():
		if output != null: output.text = "[b]Lum:[/b] Load an OpenAI API key in CMS for this session, or switch back to Ollama."
		return
	var payload := JSON.stringify({
		"model": OPENAI_MODEL,
		"instructions": "You are Lum inside KAI 9000. Human operator has final authority. Never auto-publish. Be concise and practical.",
		"input": text
	})
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + api_key.text.strip_edges()]
	var err := openai_chat.request(OPENAI_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK and output != null:
		output.text = "[b]Lum:[/b] OpenAI request could not start."

func _check_ollama() -> void:
	status_strip.text = "LUM: ONLINE  |  OLLAMA: CHECKING  |  OPENAI: %s" % ("READY" if openai_configured else "KEY NOT LOADED")
	ollama_health.request(OLLAMA_BASE + "/api/tags")

func _on_ollama_health(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	ollama_online = response_code >= 200 and response_code < 300
	_update_status_strip()

func _on_ollama_chat(_result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	if output == null: return
	if response_code < 200 or response_code >= 300:
		output.text = "[b]Lum:[/b] Ollama returned HTTP %d." % response_code
		return
	var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("message") and parsed["message"] is Dictionary:
		output.text = "[b]Lum:[/b] " + str(parsed["message"].get("content", "No response text."))
	else:
		output.text = "[b]Lum:[/b] Ollama response could not be parsed."

func _on_openai_chat(_result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	if output == null: return
	var text_body := body_bytes.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		output.text = "[b]Lum:[/b] OpenAI returned HTTP %d." % response_code
		return
	var parsed = JSON.parse_string(text_body)
	if not (parsed is Dictionary):
		output.text = "[b]Lum:[/b] OpenAI response could not be parsed."
		return
	var pieces: Array[String] = []
	for item in parsed.get("output", []):
		if item is Dictionary:
			for content in item.get("content", []):
				if content is Dictionary and content.get("type", "") == "output_text":
					pieces.append(str(content.get("text", "")))
	output.text = "[b]Lum:[/b] " + ("\n".join(pieces) if not pieces.is_empty() else "OpenAI returned no text output.")

func _on_key_changed(value: String) -> void:
	openai_configured = not value.strip_edges().is_empty()
	_update_status_strip()

func _apply_cms() -> void:
	if api_key != null:
		openai_configured = not api_key.text.strip_edges().is_empty()
	_update_status_strip()

func _refresh_status() -> void:
	_check_ollama()
	_show_status()

func _update_status_strip() -> void:
	if status_strip == null: return
	status_strip.text = "LUM: ONLINE  |  OLLAMA: %s  |  OPENAI: %s  |  ROUTE: %s" % ["ONLINE" if ollama_online else "OFFLINE", "READY" if openai_configured else "KEY NOT LOADED", provider]

func _reset_camera() -> void:
	var sanctuary := get_parent()
	if sanctuary == null: return
	if "yaw" in sanctuary: sanctuary.yaw = 0.0
	if "pitch" in sanctuary: sanctuary.pitch = -0.08
	if "distance" in sanctuary: sanctuary.distance = 4.2
