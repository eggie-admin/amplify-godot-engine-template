extends Node

const SAVE_PATH := "user://kai9000_cathedral_state.json"
const DEFAULT_SEED := 9000
const PULL_COST := 100
const PITY_LIMIT := 10

const REWARDS := [
	{"id": "lum_emote_smirk", "rarity": "R", "label": "Smirk Emote"},
	{"id": "lum_hipwing_flare", "rarity": "SR", "label": "Hip-Wing Flare"},
	{"id": "lum_tail_heart_pose", "rarity": "R", "label": "Tail Heart Pose"},
	{"id": "cathedral_particle_burst", "rarity": "SR", "label": "Cathedral Particle Burst"},
	{"id": "cathedral_outfit_token", "rarity": "SSR", "label": "Cathedral Outfit Token"},
	{"id": "sparks_cache", "rarity": "R", "label": "Sparks Cache"}
]

var host: Node3D
var lum: Node3D
var wing_left: Node3D
var wing_right: Node3D
var tail_root: Node3D
var runtime_root: Node3D
var status_label: Label
var pull_button: Button
var rng := RandomNumberGenerator.new()
var seed_value: int = DEFAULT_SEED
var sparks: int = 500
var pity_counter: int = 0
var unlocked: Array[String] = []
var flare_until_ms: int = 0


func _ready() -> void:
	process_priority = 20
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	host = get_parent() as Node3D
	if host == null:
		return
	_load_state()
	rng.seed = seed_value
	_bind_lum()
	_move_wings_to_hips()
	_build_cathedral(seed_value)
	_build_reward_ui()
	_refresh_status("ULTIMA READY")


func _bind_lum() -> void:
	lum = host.get_node_or_null("Lum") as Node3D
	if lum == null:
		return
	wing_left = lum.get_node_or_null("LeftWing") as Node3D
	wing_right = lum.get_node_or_null("RightWing") as Node3D
	tail_root = lum.get_node_or_null("Tail") as Node3D


func _move_wings_to_hips() -> void:
	if is_instance_valid(wing_left):
		wing_left.position = Vector3(-0.54, -0.06, -0.18)
		wing_left.rotation_degrees = Vector3(0.0, -4.0, -8.0)
	if is_instance_valid(wing_right):
		wing_right.position = Vector3(0.54, -0.06, -0.18)
		wing_right.rotation_degrees = Vector3(0.0, 4.0, 8.0)


func _build_cathedral(seed_for_build: int) -> void:
	if is_instance_valid(runtime_root):
		runtime_root.queue_free()

	runtime_root = Node3D.new()
	runtime_root.name = "UltimaCathedral"
	host.add_child(runtime_root)

	var build_rng := RandomNumberGenerator.new()
	build_rng.seed = seed_for_build
	var stone := _material(Color(0.055, 0.045, 0.070), 0.05, 0.78)
	var trim := _material(Color(0.23, 0.055, 0.075), 0.18, 0.52)
	var glow := _material(Color(0.02, 0.34, 0.31), 0.35, 0.24)

	# Original zero-external-asset cathedral nave. The paired columns recede behind Lum.
	for i in range(6):
		var z := -2.5 - float(i) * 2.3
		var jitter := build_rng.randf_range(-0.22, 0.22)
		var height := 3.4 + build_rng.randf_range(-0.25, 0.45)
		_add_box(runtime_root, "Floor_%02d" % i, Vector3(0.0, -1.08, z), Vector3(7.4, 0.08, 2.25), stone)
		_add_column(runtime_root, "LeftColumn_%02d" % i, Vector3(-3.0 + jitter, 0.60, z), height, stone, trim)
		_add_column(runtime_root, "RightColumn_%02d" % i, Vector3(3.0 - jitter, 0.60, z), height, stone, trim)
		_add_box(runtime_root, "ArchBeam_%02d" % i, Vector3(0.0, 2.35, z), Vector3(6.3, 0.20, 0.24), trim)

	# Altar/reward shrine at the end of the nave.
	_add_box(runtime_root, "AltarBase", Vector3(0.0, -0.50, -15.3), Vector3(2.7, 1.0, 1.3), stone)
	_add_box(runtime_root, "AltarGlow", Vector3(0.0, 0.16, -15.25), Vector3(1.45, 0.14, 0.70), glow)


func _add_column(parent: Node3D, name_text: String, position_value: Vector3, height: float, body_material: Material, trim_material: Material) -> void:
	_add_box(parent, name_text + "_Body", position_value, Vector3(0.44, height, 0.44), body_material)
	_add_box(parent, name_text + "_Base", position_value + Vector3(0.0, -height * 0.50, 0.0), Vector3(0.68, 0.18, 0.68), trim_material)
	_add_box(parent, name_text + "_Cap", position_value + Vector3(0.0, height * 0.50, 0.0), Vector3(0.70, 0.20, 0.70), trim_material)


func _add_box(parent: Node3D, name_text: String, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = position_value
	parent.add_child(instance)
	return instance


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _build_reward_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UltimaRewardLayer"
	host.add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.56
	panel.anchor_top = 0.035
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.18
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ULTIMA // RELIC SHRINE"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	pull_button = Button.new()
	pull_button.text = "GACHA PULL"
	pull_button.pressed.connect(_gacha_pull)
	row.add_child(pull_button)

	var ultima_button := Button.new()
	ultima_button.text = "CAST ULTIMA"
	ultima_button.pressed.connect(_cast_ultima)
	row.add_child(ultima_button)

	var save_button := Button.new()
	save_button.text = "SAVEPOINT"
	save_button.pressed.connect(_save_state)
	row.add_child(save_button)


func _gacha_pull() -> void:
	if sparks < PULL_COST:
		_refresh_status("NOT ENOUGH SPARKS")
		return

	sparks -= PULL_COST
	pity_counter += 1
	var reward_index := rng.randi_range(0, REWARDS.size() - 1)
	if pity_counter >= PITY_LIMIT:
		reward_index = 4
		pity_counter = 0

	var reward: Dictionary = REWARDS[reward_index]
	var reward_id := str(reward.get("id", "unknown"))
	if reward_id == "sparks_cache":
		sparks += 250
	elif not unlocked.has(reward_id):
		unlocked.append(reward_id)

	flare_until_ms = Time.get_ticks_msec() + 1500
	_save_state()
	_refresh_status("%s // %s" % [str(reward.get("rarity", "R")), str(reward.get("label", reward_id))])


func _cast_ultima() -> void:
	flare_until_ms = Time.get_ticks_msec() + 2400
	_refresh_status("ULTIMA CAST // HIP-WINGS FULL FLARE")


func _refresh_status(message: String = "") -> void:
	if not is_instance_valid(status_label):
		return
	var prefix := "SPARKS %d  |  PITY %d/%d" % [sparks, pity_counter, PITY_LIMIT]
	status_label.text = prefix if message.is_empty() else prefix + "\n" + message
	if is_instance_valid(pull_button):
		pull_button.disabled = sparks < PULL_COST


func _save_state() -> void:
	var payload := {
		"schema": 1,
		"seed": seed_value,
		"sparks": sparks,
		"pity_counter": pity_counter,
		"unlocked": unlocked,
		"rights_lane": "LUHM_ORIGINAL_ONLY"
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_refresh_status("SAVE FAILED")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	_refresh_status("SAVEPOINT SEALED")


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	seed_value = int(parsed.get("seed", DEFAULT_SEED))
	sparks = int(parsed.get("sparks", 500))
	pity_counter = int(parsed.get("pity_counter", 0))
	unlocked.clear()
	var raw_unlocks = parsed.get("unlocked", [])
	if raw_unlocks is Array:
		for item in raw_unlocks:
			unlocked.append(str(item))


func _process(_delta: float) -> void:
	if not is_instance_valid(lum):
		return
	var t := Time.get_ticks_msec() * 0.001
	var flaring := Time.get_ticks_msec() < flare_until_ms
	var flare_scale := 1.22 if flaring else 1.0

	if is_instance_valid(wing_left):
		wing_left.position = Vector3(-0.54, -0.06, -0.18)
		wing_left.rotation.y = sin(t * 2.25) * 0.20 - 0.07
		wing_left.rotation.z = sin(t * 2.25) * 0.08 - 0.14
		wing_left.scale = Vector3.ONE * flare_scale
	if is_instance_valid(wing_right):
		wing_right.position = Vector3(0.54, -0.06, -0.18)
		wing_right.rotation.y = -sin(t * 2.25) * 0.20 + 0.07
		wing_right.rotation.z = -sin(t * 2.25) * 0.08 + 0.14
		wing_right.scale = Vector3.ONE * flare_scale
	if is_instance_valid(tail_root):
		tail_root.rotation.z = sin(t * 1.35) * 0.24
