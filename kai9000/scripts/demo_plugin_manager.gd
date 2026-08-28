extends Node

signal registry_changed

const MANIFEST_DIR := "res://integrations"
const DEMO_IMPORT_ROOT := "user://demo_imports"

var registry: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEMO_IMPORT_ROOT))
	_reload_registry()


func _reload_registry() -> void:
	registry.clear()
	var dir := DirAccess.open(MANIFEST_DIR)
	if dir == null:
		registry_changed.emit()
		return
	for file_name in dir.get_files():
		if not file_name.to_lower().ends_with(".json"):
			continue
		var path := MANIFEST_DIR + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str(parsed.get("kind", "")) != "demo_plugin":
			continue
		var plugin_id := str(parsed.get("id", "")).strip_edges()
		if plugin_id.is_empty():
			continue
		registry[plugin_id] = parsed
	registry_changed.emit()


func get_registry_snapshot() -> Dictionary:
	return registry.duplicate(true)


func validate_demo_payload(plugin_id: String, file_name: String) -> Dictionary:
	if not registry.has(plugin_id):
		return {"ok": false, "reason": "unknown_plugin"}
	var manifest: Dictionary = registry[plugin_id]
	if bool(manifest.get("enabled", false)):
		return {"ok": false, "reason": "plugin_must_remain_dummy_until_professor_enables_it"}
	if not bool(manifest.get("educational_only", false)):
		return {"ok": false, "reason": "educational_only_required"}
	if bool(manifest.get("auto_download", false)):
		return {"ok": false, "reason": "auto_download_forbidden"}

	var ext := file_name.get_extension().to_lower()
	var allowed: Array = manifest.get("accepted_handoff_formats", [])
	if not allowed.has(ext):
		return {"ok": false, "reason": "unsupported_handoff_format", "extension": ext}
	return {
		"ok": true,
		"plugin": plugin_id,
		"extension": ext,
		"policy": "user_supplied_authorized_converted_assets_only"
	}


func get_import_root(plugin_id: String) -> String:
	var safe_id := plugin_id.validate_filename()
	var root := DEMO_IMPORT_ROOT + "/" + safe_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	return root
