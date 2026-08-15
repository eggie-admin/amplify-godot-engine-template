extends Node3D

const OLLAMA_BASE := "http://127.0.0.1:11434"
const OLLAMA_MODEL := "qwen3:0.6b"

var camera_pivot: Node3D
var camera: Camera3D
var avatar: Node3D
var wing_left: Node3D
var wing_right: Node3D
var tail_root: Node3D
var status_label: Label
var output: RichTextLabel
var prompt: LineEdit
var health_request: HTTPRequest
var chat_request: HTTPRequest
var yaw := 0.0
var pitch := -0.08
var distance := 4.2
var procedural_lum := false


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
	environment.background_color = Color(0.006, 0.010, 0.018)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.48, 0.55)
	environment.ambient_light_energy = 0.82
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, -26.0, 0.0)
	key_light.light_color = Color(1.0, 0.88, 0.80)
	key_light.light_energy = 1.7
	key_light.shadow_enabled = true
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-2.0, 2.5, 1.8)
	rim_light.light_color = Color(0.10, 0.95, 0.90)
	rim_light.light_energy = 1.8
	rim_light.omni_range = 8.0
	add_child(rim_light)

	var warm_light := OmniLight3D.new()
	warm_light.position = Vector3(2.2, 1.2, 1.4)
	warm_light.light_color = Color(1.0, 0.32, 0.18)
	warm_light.light_energy = 0.7
	warm_light.omni_range = 6.0
	add_child(warm_light)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	plane.material = _material(Color(0.018, 0.030, 0.040), 0.42, 0.42)
	floor.mesh = plane
	floor.position.y = -1.05
	add_child(floor)

	camera_pivot = Node3D.new()
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.15, distance)
	camera.current = true
	camera_pivot.add_child(camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	layer.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "KAI 9000  //  LUM SANCTUARY"
	title.add_theme_font_size_override("font_size", 30)
	root.add_child(title)

	var crown := Label.new()
	crown.text = "PROFESSOR  |  ADMIN: eggie"
	crown.add_theme_font_size_override("font_size", 18)
	root.add_child(crown)

	status_label = Label.new()
	status_label.text = "LUM ONLINE  |  OLLAMA: CHECKING"
	status_label.add_theme_font_size_override("font_size", 17)
	root.add_child(status_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 760.0)
	root.add_child(spacer)

	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.custom_minimum_size = Vector2(0.0, 250.0)
	output.text = "[b]Lum:[/b] I'm here, Professor."
	root.add_child(output)

	prompt = LineEdit.new()
	prompt.placeholder_text = "Speak to Lum..."
	prompt.text_submitted.connect(_on_text_submitted)
	root.add_child(prompt)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var send_button := Button.new()
	send_button.text = "TALK TO LUM"
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

	_build_lum_avatar()


func _build_lum_avatar() -> void:
	procedural_lum = true
	avatar = Node3D.new()
	avatar.name = "Lum"
	avatar.position = Vector3(0.0, 0.05, 0.0)
	add_child(avatar)

	var skin := _material(Color(0.91, 0.66, 0.55), 0.0, 0.62)
	var skin_soft := _material(Color(0.96, 0.73, 0.63), 0.0, 0.58)
	var hair := _material(Color(0.38, 0.105, 0.055), 0.05, 0.42)
	var hair_light := _material(Color(0.62, 0.19, 0.08), 0.04, 0.40)
	var black := _material(Color(0.012, 0.014, 0.020), 0.12, 0.34)
	var charcoal := _material(Color(0.035, 0.040, 0.050), 0.18, 0.36)
	var white := _material(Color(0.92, 0.95, 0.96), 0.02, 0.42)
	var teal := _material(Color(0.03, 0.86, 0.78), 0.18, 0.28)
	var iris := _material(Color(0.02, 0.36, 0.30), 0.05, 0.30)
	var wing_mat := _material(Color(0.13, 0.018, 0.035), 0.12, 0.38)
	var wing_edge := _material(Color(0.46, 0.035, 0.065), 0.08, 0.36)
	var horn_mat := _material(Color(0.10, 0.025, 0.030), 0.15, 0.33)

	# Legs and shoes.
	_add_capsule("LeftLeg", Vector3(-0.24, -0.42, 0.0), Vector3(0.17, 0.72, 0.17), charcoal)
	_add_capsule("RightLeg", Vector3(0.24, -0.42, 0.0), Vector3(0.17, 0.72, 0.17), charcoal)
	_add_box("LeftShoe", Vector3(-0.24, -0.94, 0.10), Vector3(0.22, 0.12, 0.36), black)
	_add_box("RightShoe", Vector3(0.24, -0.94, 0.10), Vector3(0.22, 0.12, 0.36), black)

	# Executive black dress.
	var dress_mesh := CylinderMesh.new()
	dress_mesh.top_radius = 0.42
	dress_mesh.bottom_radius = 0.66
	dress_mesh.height = 1.22
	dress_mesh.radial_segments = 32
	dress_mesh.material = black
	var dress := MeshInstance3D.new()
	dress.name = "ExecutiveDress"
	dress.mesh = dress_mesh
	dress.position = Vector3(0.0, 0.20, 0.0)
	avatar.add_child(dress)

	# Torso and shoulders give her an actual silhouette instead of a stick figure.
	_add_sphere("Torso", Vector3(0.0, 0.72, 0.0), Vector3(0.55, 0.46, 0.34), black)
	_add_sphere("LeftShoulder", Vector3(-0.47, 0.72, 0.0), Vector3(0.22, 0.20, 0.22), black)
	_add_sphere("RightShoulder", Vector3(0.47, 0.72, 0.0), Vector3(0.22, 0.20, 0.22), black)

	# White secretary collar and teal brooch.
	_add_box("LeftCollar", Vector3(-0.15, 1.02, 0.30), Vector3(0.28, 0.07, 0.12), white, Vector3(0.0, 0.0, -18.0))
	_add_box("RightCollar", Vector3(0.15, 1.02, 0.30), Vector3(0.28, 0.07, 0.12), white, Vector3(0.0, 0.0, 18.0))
	_add_sphere("Brooch", Vector3(0.0, 0.96, 0.37), Vector3(0.075, 0.075, 0.045), teal)

	# Sleeves, arms and hands.
	_add_capsule("LeftSleeve", Vector3(-0.57, 0.44, 0.0), Vector3(0.16, 0.38, 0.16), black, Vector3(0.0, 0.0, -10.0))
	_add_capsule("RightSleeve", Vector3(0.57, 0.44, 0.0), Vector3(0.16, 0.38, 0.16), black, Vector3(0.0, 0.0, 10.0))
	_add_capsule("LeftForearm", Vector3(-0.63, 0.06, 0.05), Vector3(0.12, 0.31, 0.12), skin, Vector3(0.0, 0.0, -5.0))
	_add_capsule("RightForearm", Vector3(0.63, 0.06, 0.05), Vector3(0.12, 0.31, 0.12), skin, Vector3(0.0, 0.0, 5.0))
	_add_sphere("LeftHand", Vector3(-0.66, -0.18, 0.08), Vector3(0.13, 0.16, 0.10), skin_soft)
	_add_sphere("RightHand", Vector3(0.66, -0.18, 0.08), Vector3(0.13, 0.16, 0.10), skin_soft)

	# Neck and face.
	_add_capsule("Neck", Vector3(0.0, 1.10, 0.0), Vector3(0.16, 0.20, 0.16), skin)
	_add_sphere("Head", Vector3(0.0, 1.48, 0.0), Vector3(0.43, 0.52, 0.40), skin_soft)
	_add_sphere("LeftEar", Vector3(-0.42, 1.49, 0.0), Vector3(0.09, 0.14, 0.07), skin)
	_add_sphere("RightEar", Vector3(0.42, 1.49, 0.0), Vector3(0.09, 0.14, 0.07), skin)

	# Large expressive eyes, brows, nose and mouth.
	_add_sphere("LeftEyeWhite", Vector3(-0.16, 1.55, 0.355), Vector3(0.135, 0.095, 0.045), white)
	_add_sphere("RightEyeWhite", Vector3(0.16, 1.55, 0.355), Vector3(0.135, 0.095, 0.045), white)
	_add_sphere("LeftIris", Vector3(-0.16, 1.55, 0.395), Vector3(0.070, 0.065, 0.030), iris)
	_add_sphere("RightIris", Vector3(0.16, 1.55, 0.395), Vector3(0.070, 0.065, 0.030), iris)
	_add_sphere("LeftPupil", Vector3(-0.16, 1.55, 0.420), Vector3(0.032, 0.045, 0.018), black)
	_add_sphere("RightPupil", Vector3(0.16, 1.55, 0.420), Vector3(0.032, 0.045, 0.018), black)
	_add_box("LeftBrow", Vector3(-0.16, 1.70, 0.375), Vector3(0.16, 0.025, 0.025), hair, Vector3(0.0, 0.0, -7.0))
	_add_box("RightBrow", Vector3(0.16, 1.70, 0.375), Vector3(0.16, 0.025, 0.025), hair, Vector3(0.0, 0.0, 7.0))
	_add_sphere("Nose", Vector3(0.0, 1.43, 0.405), Vector3(0.055, 0.075, 0.050), skin)
	_add_box("Mouth", Vector3(0.0, 1.31, 0.397), Vector3(0.13, 0.022, 0.018), wing_edge)

	# Auburn updo with bun and side locks.
	_add_sphere("HairCap", Vector3(0.0, 1.70, -0.05), Vector3(0.48, 0.42, 0.43), hair)
	_add_sphere("HairFront", Vector3(0.12, 1.80, 0.24), Vector3(0.34, 0.16, 0.16), hair_light, Vector3(0.0, 0.0, -10.0))
	_add_sphere("Bun", Vector3(0.0, 2.03, -0.13), Vector3(0.30, 0.31, 0.27), hair)
	_add_capsule("LeftLock", Vector3(-0.40, 1.37, 0.06), Vector3(0.09, 0.28, 0.10), hair)
	_add_capsule("RightLock", Vector3(0.40, 1.37, 0.06), Vector3(0.09, 0.28, 0.10), hair)

	# Oni horns.
	_add_horn("LeftHorn", Vector3(-0.27, 1.99, -0.02), horn_mat, Vector3(0.0, 0.0, 22.0))
	_add_horn("RightHorn", Vector3(0.27, 1.99, -0.02), horn_mat, Vector3(0.0, 0.0, -22.0))

	# Bat wings behind the shoulders.
	wing_left = Node3D.new()
	wing_left.name = "LeftWing"
	wing_left.position = Vector3(-0.44, 0.84, -0.16)
	avatar.add_child(wing_left)
	_add_box_to(wing_left, "LWingUpper", Vector3(-0.42, 0.14, 0.0), Vector3(0.72, 0.11, 0.055), wing_mat, Vector3(0.0, -8.0, -28.0))
	_add_box_to(wing_left, "LWingMid", Vector3(-0.62, -0.12, 0.0), Vector3(0.62, 0.13, 0.050), wing_mat, Vector3(0.0, -5.0, 18.0))
	_add_box_to(wing_left, "LWingTip", Vector3(-0.74, -0.34, 0.0), Vector3(0.46, 0.11, 0.045), wing_edge, Vector3(0.0, -4.0, 36.0))

	wing_right = Node3D.new()
	wing_right.name = "RightWing"
	wing_right.position = Vector3(0.44, 0.84, -0.16)
	avatar.add_child(wing_right)
	_add_box_to(wing_right, "RWingUpper", Vector3(0.42, 0.14, 0.0), Vector3(0.72, 0.11, 0.055), wing_mat, Vector3(0.0, 8.0, 28.0))
	_add_box_to(wing_right, "RWingMid", Vector3(0.62, -0.12, 0.0), Vector3(0.62, 0.13, 0.050), wing_mat, Vector3(0.0, 5.0, -18.0))
	_add_box_to(wing_right, "RWingTip", Vector3(0.74, -0.34, 0.0), Vector3(0.46, 0.11, 0.045), wing_edge, Vector3(0.0, 4.0, -36.0))

	# Devil tail, visible over her right side from the front camera.
	tail_root = Node3D.new()
	tail_root.name = "Tail"
	tail_root.position = Vector3(0.30, -0.05, -0.22)
	avatar.add_child(tail_root)
	_add_capsule_to(tail_root, "Tail1", Vector3(0.28, -0.20, 0.0), Vector3(0.085, 0.33, 0.085), wing_edge, Vector3(0.0, 0.0, -48.0))
	_add_capsule_to(tail_root, "Tail2", Vector3(0.53, -0.36, 0.0), Vector3(0.075, 0.29, 0.075), wing_edge, Vector3(0.0, 0.0, -68.0))
	_add_capsule_to(tail_root, "Tail3", Vector3(0.70, -0.22, 0.0), Vector3(0.065, 0.26, 0.065), wing_edge, Vector3(0.0, 0.0, 25.0))
	_add_sphere_to(tail_root, "TailTip", Vector3(0.78, -0.04, 0.0), Vector3(0.11, 0.15, 0.05), wing_edge, Vector3(0.0, 0.0, -18.0))

	# A small teal halo platform under Lum to visually anchor the avatar.
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 0.86
	platform_mesh.bottom_radius = 0.96
	platform_mesh.height = 0.06
	platform_mesh.radial_segments = 48
	platform_mesh.material = _material(Color(0.01, 0.38, 0.36), 0.55, 0.20)
	var platform := MeshInstance3D.new()
	platform.mesh = platform_mesh
	platform.position = Vector3(0.0, -1.00, 0.0)
	avatar.add_child(platform)


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _add_sphere(name_text: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add_sphere_to(avatar, name_text, position_value, scale_value, material, rotation_value)


func _add_sphere_to(parent: Node3D, name_text: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value * 2.0
	instance.rotation_degrees = rotation_value
	parent.add_child(instance)
	return instance


func _add_capsule(name_text: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add_capsule_to(avatar, name_text, position_value, scale_value, material, rotation_value)


func _add_capsule_to(parent: Node3D, name_text: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value * 2.0
	instance.rotation_degrees = rotation_value
	parent.add_child(instance)
	return instance


func _add_box(name_text: String, position_value: Vector3, size_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add_box_to(avatar, name_text, position_value, size_value, material, rotation_value)


func _add_box_to(parent: Node3D, name_text: String, position_value: Vector3, size_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	parent.add_child(instance)
	return instance


func _add_horn(name_text: String, position_value: Vector3, material: Material, rotation_value: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.13
	mesh.height = 0.48
	mesh.radial_segments = 18
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	avatar.add_child(instance)
	return instance


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
	status_label.text = "LUM ONLINE  |  OLLAMA: CHECKING"
	var error := health_request.request(OLLAMA_BASE + "/api/tags")
	if error != OK:
		status_label.text = "LUM ONLINE  |  OLLAMA: LOCAL CONNECTION ERROR"


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
				"content": "You are Lum inside KAI 9000 Sanctuary. Professor holds final authority. You are a warm, confident adult oni executive assistant with playful energy. Keep operational replies concise."
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
		output.text += "\n\n[b]Lum:[/b] I can't reach the local boss yet."


func _on_text_submitted(_text: String) -> void:
	_send_prompt()


func _on_health_response(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		status_label.text = "LUM ONLINE  |  OLLAMA: GREEN"
	else:
		status_label.text = "LUM ONLINE  |  OLLAMA: WAITING"


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

	if procedural_lum and is_instance_valid(avatar):
		var t := Time.get_ticks_msec() * 0.001
		avatar.position.y = 0.05 + sin(t * 1.45) * 0.035
		avatar.rotation.y = sin(t * 0.52) * 0.035
		if is_instance_valid(wing_left):
			wing_left.rotation.y = sin(t * 2.0) * 0.16
			wing_left.rotation.z = sin(t * 2.0) * 0.05
		if is_instance_valid(wing_right):
			wing_right.rotation.y = -sin(t * 2.0) * 0.16
			wing_right.rotation.z = -sin(t * 2.0) * 0.05
		if is_instance_valid(tail_root):
			tail_root.rotation.z = sin(t * 1.25) * 0.18


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.006
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.006
