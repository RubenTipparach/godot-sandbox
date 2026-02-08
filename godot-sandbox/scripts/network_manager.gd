extends Node

## Network manager autoload - handles WebRTC P2P connection via signaling server

signal connection_established
signal connection_failed(reason: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

enum NetRole { NONE, HOST, CLIENT }

var role: NetRole = NetRole.NONE
var room_id: String = ""
var signaling_base_url: String = ""
var is_connected: bool = false
var poll_timer: float = 0.0
const POLL_INTERVAL: float = 0.5

var rtc_peer: WebRTCPeerConnection
var mp_peer: WebRTCMultiplayerPeer


func _ready():
	if OS.has_feature("web"):
		signaling_base_url = str(JavaScriptBridge.eval("window.location.origin")) + "/api"
	else:
		signaling_base_url = "http://localhost:3000/api"
	set_process(false)


func is_host() -> bool:
	return role == NetRole.HOST or role == NetRole.NONE


func is_multiplayer_active() -> bool:
	return role != NetRole.NONE and is_connected


func get_player_count() -> int:
	if not is_multiplayer_active():
		return 1
	return multiplayer.get_peers().size() + 1


func create_room() -> String:
	var http = HTTPRequest.new()
	add_child(http)
	var err = http.request(signaling_base_url + "/create-room",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST, "{}")
	if err != OK:
		http.queue_free()
		connection_failed.emit("HTTP request failed")
		return ""
	var result = await http.request_completed
	http.queue_free()
	var body = result[3] as PackedByteArray
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("room_id"):
		room_id = json["room_id"]
		role = NetRole.HOST
		_setup_webrtc_host()
		return room_id
	connection_failed.emit("Invalid server response")
	return ""


func join_room(code: String):
	room_id = code.to_upper()
	role = NetRole.CLIENT
	var http = HTTPRequest.new()
	add_child(http)
	var err = http.request(signaling_base_url + "/join-room",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"room_id": room_id}))
	if err != OK:
		http.queue_free()
		connection_failed.emit("HTTP request failed")
		return
	var result = await http.request_completed
	http.queue_free()
	var body = result[3] as PackedByteArray
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or not json.get("success", false):
		connection_failed.emit("Room not found")
		role = NetRole.NONE
		return
	_setup_webrtc_client()


func disconnect_peer():
	is_connected = false
	role = NetRole.NONE
	room_id = ""
	set_process(false)
	if mp_peer:
		mp_peer.close()
		mp_peer = null
	if rtc_peer:
		rtc_peer.close()
		rtc_peer = null
	multiplayer.multiplayer_peer = null


func _setup_webrtc_host():
	rtc_peer = WebRTCPeerConnection.new()
	rtc_peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
	rtc_peer.ice_candidate_created.connect(_on_ice_candidate)
	rtc_peer.session_description_created.connect(_on_session_description)

	mp_peer = WebRTCMultiplayerPeer.new()
	mp_peer.create_server()
	mp_peer.add_peer(rtc_peer, 2)  # Client will be peer 2
	multiplayer.multiplayer_peer = mp_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(true)


func _setup_webrtc_client():
	rtc_peer = WebRTCPeerConnection.new()
	rtc_peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
	rtc_peer.ice_candidate_created.connect(_on_ice_candidate)
	rtc_peer.session_description_created.connect(_on_session_description)

	mp_peer = WebRTCMultiplayerPeer.new()
	mp_peer.create_client(2)  # Client is peer 2
	mp_peer.add_peer(rtc_peer, 1)
	multiplayer.multiplayer_peer = mp_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Client creates offer
	rtc_peer.create_offer()
	set_process(true)


func _on_session_description(type: String, sdp: String):
	rtc_peer.set_local_description(type, sdp)
	_send_signal(type, {"sdp": sdp})


func _on_ice_candidate(media: String, index: int, name: String):
	_send_signal("ice", {"media": media, "index": index, "name": name})


func _process(delta):
	if role == NetRole.NONE:
		return
	if mp_peer:
		mp_peer.poll()
	if not is_connected:
		poll_timer += delta
		if poll_timer >= POLL_INTERVAL:
			poll_timer = 0.0
			_poll_signals()


func _poll_signals():
	var role_str = "host" if role == NetRole.HOST else "client"
	var http = HTTPRequest.new()
	add_child(http)
	var err = http.request(signaling_base_url + "/poll?room_id=" + room_id + "&as=" + role_str)
	if err != OK:
		http.queue_free()
		return
	var result = await http.request_completed
	http.queue_free()
	var body = result[3] as PackedByteArray
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("messages"):
		for msg in json["messages"]:
			_handle_signal(msg)


func _send_signal(type: String, data: Dictionary):
	var role_str = "host" if role == NetRole.HOST else "client"
	var http = HTTPRequest.new()
	add_child(http)
	http.request(signaling_base_url + "/signal",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"room_id": room_id,
			"from": role_str,
			"type": type,
			"data": data
		}))
	await http.request_completed
	http.queue_free()


func _handle_signal(msg: Dictionary):
	var data = msg.get("data", {})
	match msg.get("type", ""):
		"offer":
			rtc_peer.set_remote_description("offer", data.get("sdp", ""))
			# Host creates answer after receiving offer
			if role == NetRole.HOST:
				rtc_peer.create_answer()
		"answer":
			rtc_peer.set_remote_description("answer", data.get("sdp", ""))
		"ice":
			rtc_peer.add_ice_candidate(
				data.get("media", ""),
				data.get("index", 0),
				data.get("name", ""))


func _on_peer_connected(id: int):
	is_connected = true
	peer_connected.emit(id)
	connection_established.emit()


func _on_peer_disconnected(id: int):
	peer_disconnected.emit(id)
	if multiplayer.get_peers().size() == 0:
		is_connected = false
