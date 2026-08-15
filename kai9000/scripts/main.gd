extends Node3D

const OLLAMA_BASE := "http://127.0.0.1:11434"
const OLLAMA_MODEL := "qwen3:0.6b"

var camera_pivot: Node3D
var camera: Camera3D
var avatar: Node3D
var status_label: Label
var output: RichTextLabel
var prompt: LineEdit
var health_request: HTTPRequest
var chat_request: HTTPRequest
var yaw := 0.0
var pitch := -0.08
var distance := 4.2


func _ready() -> void:
	_build_world()
	_build_ui()
	_load_avatar()
	_setup_network()
	_check_ollama()


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.015, 0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.55, 0.62)
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -24.0, 0.0)
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-2.0, 2.4, 1.4)
	rim_light.light_energy = 1.0
	rim_light.omni_range = 8.0
	add_child(rim_light)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.045, 0.055)
	material.metallic = 0.3
	material.roughness = 0.5
	plane.material = material
	floor.mesh = plane
	floor.position.y = -1.0
	add_child(floor)

	camera_pivot = Node3D.new()
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.2, distance)
	camera.current = true
	camera_pivot.add_child(camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	layer.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "KAI 9000 SANCTUARY"
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	var crown := Label.new()
	crown.text = "PROFESSOR  |  ADMIN: eggie"
	crown.add_theme_font_size_override("font_size", 20)
	root.add_child(crown)

	status_label = Label.new()
	status_label.text = "OLLAMA: CHECKING  |  OPENAI: COMPATIBILITY LAYER"
	status_label.add_theme_font_size_override("font_size", 18)
	root.add_child(status_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 820.0)
	root.add_child(spacer)

	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.custom_minimum_size = Vector2(0.0, 300.0)
	output.text = "[b]Lum:[/b] Sanctuary APK online."
	root.add_child(output)

	prompt = LineEdit.new()
	prompt.placeholder_text = "Speak to Lum..."
	prompt.text_submitted.connect(_on_text_submitted)
	root.add_child(prompt)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var send_button := Button.new()
	send_button.text = "SEND TO LOCAL BOSS"
	send_button.pressed.connect(_send_prompt)
	buttons.add_child(send_button)

	var check_button := Button.new()
	check_button.text = "CHECK OLLAMA"
	check_button.pressed.connect(_check_ollama)
	buttons.add_child(check_button)


func _load_avatar() -> void:
	const avatar_path := "res://assets/avatar.glb"
	if ResourceLoader.exists(avatar_path):
		var packed = load(avatar_path)
		if packed is PackedScene:
			avatar = packed.instantiate()
			add_child(avatar)
			return

	var fallback := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 2.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.75, 0.68)
	material.metallic = 0.35
	material.roughness = 0.3
	mesh.material = material
	fallback.mesh = mesh
	avatar = fallback
	add_child(fallback)


func _setup_network() -> void:
	health_request = HTTPRequest.new()
	add_child(health_request)
	health_request.request_completed.connect(_on_health_response)
	chat_request = HTTPRequest.new()
	add_child(chat_request)
	chat_request.request_completed.connect(_on_chat_response)


func _check_ollama() -> void:
	if health_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	status_label.text = "OLLAMA: CHECKING..."
	var error := health_request.request(OLLAMA_BASE + "/api/tags")
	if error != OK:
		status_label.text = "OLLAMA: LOCAL CONNECTION ERROR"


func _send_prompt() -> void:
	var text := prompt.text.strip_edges()
	if text.is_empty():
		return
	if chat_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	output.text = "[b]Professor:[/b] " + text
	prompt.clear()

	var payload := JSON.stringify({
		"model": OLLAMA_MODEL,
		"messages": [
			{
				"role": "system",
				"content": "You are Lum inside KAI 9000 Sanctuary. Professor holds final authority. Keep operational replies concise."
			},
			{
				"role": "user",
				"content": text
			}
		],
		"stream": false
	})

	var error := chat_request.request(
		OLLAMA_BASE + "/v1/chat/completions",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		payload
	)
	if error != OK:
		output.text += "\n\n[b]Lum:[/b] Could not reach Ollama."


func _on_text_submitted(_text: String) -> void:
	_send_prompt()


func _on_health_response(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		status_label.text = "OLLAMA: GREEN  |  KAI 9000: READY"
	else:
		status_label.text = "OLLAMA: WAITING ON LOCAL SERVICE"


func _on_chat_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		output.text += "\n\n[b]Lum:[/b] Ollama is unavailable."
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		output.text += "\n\n[b]Lum:[/b] Invalid local-model response."
		return

	var choices = parsed.get("choices", [])
	if choices.is_empty():
		output.text += "\n\n[b]Lum:[/b] No response generated."
		return

	var message = choices[0].get("message", {})
	output.text += "\n\n[b]Lum:[/b] " + str(message.get("content", ""))


func _process(_delta: float) -> void:
	pitch = clamp(pitch, -1.1, 0.85)
	camera_pivot.rotation.x = pitch
	camera_pivot.rotation.y = yaw
	camera.position.z = distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.006
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.006
