extends CanvasLayer

const HF_API := "https://huggingface.co/api/models"

var request: HTTPRequest
var panel: PanelContainer
var query_input: LineEdit
var results: RichTextLabel
var search_button: Button


func _ready() -> void:
	_build_ui()
	request = HTTPRequest.new()
	request.use_threads = true
	request.request_completed.connect(_on_request_completed)
	add_child(request)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var toggle := Button.new()
	toggle.text = "HF CATALOG"
	toggle.position = Vector2(22.0, 22.0)
	toggle.size = Vector2(165.0, 52.0)
	toggle.pressed.connect(_toggle_panel)
	root.add_child(toggle)

	panel = PanelContainer.new()
	panel.position = Vector2(22.0, 90.0)
	panel.size = Vector2(720.0, 650.0)
	panel.visible = false
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "HUGGING FACE // CATALOG ONLY"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var policy := Label.new()
	policy.text = "Metadata browser only. No token storage, no model download, no inference. Ollama remains KAI's only runtime brain."
	policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(policy)

	query_input = LineEdit.new()
	query_input.placeholder_text = "Search model metadata, e.g. GGUF"
	query_input.text_submitted.connect(_search_from_submit)
	box.add_child(query_input)

	search_button = Button.new()
	search_button.text = "SEARCH PUBLIC HUB"
	search_button.pressed.connect(_search)
	box.add_child(search_button)

	results = RichTextLabel.new()
	results.bbcode_enabled = true
	results.custom_minimum_size = Vector2(0.0, 420.0)
	results.text = "[i]Nothing queried yet.[/i]"
	box.add_child(results)


func _toggle_panel() -> void:
	panel.visible = not panel.visible


func _search_from_submit(_text: String) -> void:
	_search()


func _search() -> void:
	var query := query_input.text.strip_edges()
	if query.is_empty():
		return
	if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	search_button.disabled = true
	results.text = "Searching public metadata..."
	var url := HF_API + "?search=" + query.uri_encode() + "&limit=8&sort=downloads&direction=-1"
	var error := request.request(url)
	if error != OK:
		search_button.disabled = false
		results.text = "Request could not be started."


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	search_button.disabled = false
	if response_code != 200:
		results.text = "Hugging Face metadata unavailable. HTTP " + str(response_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		results.text = "Unexpected catalog response."
		return
	var lines: Array[String] = []
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var model_id := str(item.get("id", "unknown"))
		var pipeline := str(item.get("pipeline_tag", "unspecified"))
		var downloads := int(item.get("downloads", 0))
		var likes := int(item.get("likes", 0))
		lines.append("[b]" + model_id + "[/b]\n  " + pipeline + "  |  downloads " + str(downloads) + "  |  likes " + str(likes))
	results.text = "\n\n".join(lines) if not lines.is_empty() else "No matching public metadata."
