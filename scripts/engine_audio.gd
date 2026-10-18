extends AudioStreamPlayer
## Synthesised V6 turbo-hybrid engine: idle growl to high scream, boost intake surge.

@export var car_path: NodePath

const RATE := 22050.0

var car: CharacterBody3D
var _pb: AudioStreamGeneratorPlayback
var _ph := 0.0
var _ph2 := 0.0
var _f := 210.0
var _vol := 0.2

func _ready() -> void:
	car = get_node(car_path)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	stream = gen
	if AudioServer.get_bus_index("SFX") != -1:
		bus = &"SFX"
	volume_db = -8.0
	play()
	_pb = get_stream_playback()

func _process(_delta: float) -> void:
	if _pb == null:
		return
	var thr: float = car.throttle_in
	var target_f: float = car.rpm / 60.0 * 3.0
	var target_v := 0.16 + 0.3 * thr + (0.1 if car.boosting else 0.0)
	var whine := 0.12 if car.boosting else 0.03
	var inc := TAU / RATE
	var n := _pb.get_frames_available()
	for i in n:
		_f += (target_f - _f) * 0.0015
		_vol += (target_v - _vol) * 0.001
		_ph = fmod(_ph + _f * inc, TAU * 2.0)
		_ph2 = fmod(_ph2 + _f * 2.7 * inc, TAU)
		var s := sin(_ph) * 0.5 + sin(_ph * 2.0) * 0.28 + sin(_ph * 3.0) * 0.16 \
			+ sin(_ph * 0.5) * 0.3 + sin(_ph * 4.0) * 0.08
		s += (randf() - 0.5) * 0.12 * (0.4 + thr)
		s += sin(_ph2) * whine
		s = tanh(s * 1.6) * _vol
		_pb.push_frame(Vector2(s, s))
