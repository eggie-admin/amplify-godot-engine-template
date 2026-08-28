extends "res://scripts/main.gd"

const KAI_BASE := "https://127.0.0.1:8798"
const KAI_MODEL := "qwen3:0.6b"

var kai_session_id := "android-" + str(Time.get_unix_time_from_system()) + "-" + str(randi())


func _setup_network() -> void:
	health_request = HTTPRequest.new()
	health_request.use_threads = true
	add_child(health_request)
	health_request.request_completed.connect(_on_health_response)

	chat_request = HTTPRequest.new()
	chat_request.use_threads = true
	add_child(chat_request)
	chat_request.request_completed.connect(_on_chat_response)

	# Loopback TLS v0.1. Encryption is on; certificate pinning is the next hardening step.
	var local_tls := TLSOptions.client_unsafe()
	health_request.set_tls_options(local_tls)
	chat_request.set_tls_options(local_tls)


func _check_ollama() -> void:
	if health_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	status_label.text = "LUM ONLINE  |  KAI HEADLESS: CHECKING"
	var error := health_request.request(KAI_BASE + "/health")
	if error != OK:
		status_label.text = "LUM ONLINE  |  KAI HEADLESS: LOCAL CONNECTION ERROR"


func _send_prompt() -> void:
	var text := prompt.text.strip_edges()
	if text.is_empty():
		return
	if chat_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	output.text = "[b]Professor:[/b] " + text
	prompt.clear()

	var payload := JSON.stringify({
		"model": KAI_MODEL,
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
		KAI_BASE + "/v1/chat/completions",
		[
			"Content-Type: application/json",
			"X-KAI-Session: " + kai_session_id
		],
		HTTPClient.METHOD_POST,
		payload
	)
	if error != OK:
		output.text += "\n\n[b]Lum:[/b] KAI headless is not reachable yet."


func _on_health_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "LUM ONLINE  |  KAI HEADLESS: WAITING"
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "LUM ONLINE  |  KAI HEADLESS: INVALID HEALTH"
		return

	var ollama_state := str(parsed.get("ollama", "unknown")).to_upper()
	status_label.text = "KAI HEADLESS: GREEN  |  OLLAMA: " + ollama_state
