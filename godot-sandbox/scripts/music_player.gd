extends Node
## MusicPlayer class is setup as an autoload so that it can play seamlessly through different instantiated scenes if needed

const BATTLE_INTRO = preload("uid://c4cvjvvjsmxsb") # Not sure if UID is better/worse/equal than using file location
const BATTLE_LOOP = preload("uid://rsxc1vuj2xlc")
const PRE_BOSS = preload("uid://5vejjxqbjfwk")

var default_crossfade_time: float = 2.5
var current_player: AudioStreamPlayer # The audiostreamplayer that is actively playing right now

@onready var battle_audio: AudioStreamPlayer = $BattleAudio
@onready var build_audio: AudioStreamPlayer = $BuildAudio
@onready var menu_audio: AudioStreamPlayer = $MenuAudio

func _ready() -> void:
	battle_audio.finished.connect(on_battle_audio_stream_finished)

func game_started():
	start_build_music()

func start_battle_music():
	battle_audio.stream = BATTLE_INTRO
	cross_fade(battle_audio, current_player)
	current_player = battle_audio
	battle_audio.play(0)

func start_build_music():
	cross_fade(build_audio, current_player)
	current_player = build_audio
	build_audio.play(0)

func start_menu_music():
	pass

func player_died():
	build_audio.stop()

func cross_fade(fade_in: AudioStreamPlayer, fade_out: AudioStreamPlayer, time: float = default_crossfade_time):
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(fade_in, "volume_linear", 1, time)
	if !fade_out: # If there's no current player there's nothing to fade out
		return
	if fade_in == fade_out: # Don't fade out what you're trying to fade in ya dummy
		return
	fade_in_tween.parallel()
	var fade_out_tween = create_tween()
	fade_out_tween.tween_callback(func(): fade_out.stop()) # Stop the player once it reaches 0 volume
	fade_out_tween.tween_property(fade_out, "volume_linear", 0, time)

func on_battle_audio_stream_finished():
	if battle_audio.stream == BATTLE_INTRO:
		battle_audio.stream = BATTLE_LOOP
		battle_audio.play(0)
