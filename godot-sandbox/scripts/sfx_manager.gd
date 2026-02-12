extends Node

const SOUNDS = {
	"shoot": preload("res://resources/sounds/picotron/shoot.ogg"),
	"impact": preload("res://resources/sounds/picotron/impact.ogg"),
	"explode_small": preload("res://resources/sounds/picotron/explode_small.ogg"),
	"levelup": preload("res://resources/sounds/picotron/levelup.ogg"),
	"pickup": preload("res://resources/sounds/picotron/pickup.ogg"),
	"orepickup": preload("res://resources/sounds/picotron/orepickup.ogg"),
}

# Per-sound volume offsets in dB
const VOLUMES = {
	"shoot": -6,
	"impact": 0.0,
	"explode_small": 0.0,
	"levelup": -4,
	"pickup": -1,
	"orepickup": 0,
}

var players: Array[AudioStreamPlayer] = []


func _ready():
	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)


func play(sound_name: String, volume_db: float = NAN):
	var stream = SOUNDS.get(sound_name)
	if not stream:
		return
	var vol = volume_db if not is_nan(volume_db) else VOLUMES.get(sound_name, 0.0)
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = vol
			p.play()
			return
	# All players busy - reuse the first one
	players[0].stream = stream
	players[0].volume_db = vol
	players[0].play()
