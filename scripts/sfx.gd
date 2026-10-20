extends Node
## Procedural audio bank. Every sample is synthesised once at boot into an
## AudioStreamWAV, so the game needs no audio files on disk.
## One-shots: play("impact"). Continuous layers: set_loop("squeal", 0..1).

const RATE := 22050
const POOL := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary = {}

func _ready() -> void:
	add_to_group("sfx")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_build()

## Fire a one-shot. Unknown names are ignored so callers never need to guard.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Continuous layer crossfaded by level (0 silences it). Used for tyre squeal
## and rain, where the volume tracks a live value instead of firing an event.
func set_loop(sound: String, level: float, bus := "SFX") -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = bus
		p.stream = _streams[sound]
		add_child(p)
		p.play()
		_loops[sound] = p
	var lvl := clampf(level, 0.0, 1.0)
	p.volume_db = linear_to_db(maxf(lvl, 0.0001))
	p.stream_paused = lvl <= 0.001

# ---------- synthesis ----------

func _build() -> void:
	_streams["beep"] = _tone(660.0, 0.18, 7.0, 0.4, 2)
	_streams["beep_go"] = _tone(1320.0, 0.55, 3.2, 0.45, 3)
	_streams["lap"] = _chime([784.0, 1046.0], 0.13, 0.3)
	_streams["best"] = _chime([880.0, 1174.0, 1568.0], 0.11, 0.3)
	_streams["finish"] = _chime([523.0, 659.0, 784.0, 1046.0], 0.14, 0.45)
	_streams["impact"] = _impact(0.5, 0.8)
	_streams["clunk"] = _impact(0.24, 0.4)
	_streams["siren"] = _siren(1.6)
	_streams["squeal"] = _squeal(0.9)
	_streams["rain"] = _rain(2.2)
	_streams["music"] = _music(8.0)
	for k in ["squeal", "rain", "music"]:
		var s: AudioStreamWAV = _streams[k]
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2

## 16-bit mono PCM. Clamped so a hot sum cannot wrap around into a click.
func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	s.data = bytes
	return s

## Simple decaying harmonic tone: the countdown beeps and race-start blast.
func _tone(freq: float, dur: float, decay: float, vol: float, harmonics: int) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * minf(t * 400.0, 1.0)
		var v := 0.0
		for h in harmonics:
			v += sin(TAU * freq * float(h + 1) * t) / float(h + 1)
		buf[i] = v * env * vol
	return _to_wav(buf)

## Ordered notes, each with its own decay: lap chimes and the finish fanfare.
func _chime(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var per := int(note_dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(per * freqs.size() + int(0.25 * RATE))
	for k in freqs.size():
		var f: float = freqs[k]
		for i in per:
			var t := float(i) / RATE
			var env := exp(-t * 5.0)
			var v := sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.22
			buf[k * per + i] += v * env * vol
	return _to_wav(buf)

## Noise burst over a low thump: barrier contact and the pit gun.
func _impact(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 11.0)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		var thump := sin(TAU * 62.0 * t) * exp(-t * 8.0)
		buf[i] = (lp * 0.7 + thump * 0.8) * env * vol
	return _to_wav(buf)

## Two-tone race-control siren; long enough to read as an alert.
func _siren(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var f := 520.0
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(t, 0.5)
		var target := 520.0 if phase < 0.25 else 760.0
		f = lerpf(f, target, 0.002)
		var env := minf(t * 8.0, 1.0) * minf((dur - t) * 8.0, 1.0)
		buf[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.12) * env * 0.5
	return _to_wav(buf)

## Continuous tyre squeal: a wobbling tone under a narrow noise band.
func _squeal(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var wob := sin(TAU * 5.5 * t) * 60.0
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.5)
		var tone := sin(TAU * (940.0 + wob) * t) * 0.45
		buf[i] = tone + lp * 0.35
	return _to_wav(_seamless(buf))

## Rain hiss: filtered noise with the loop join crossfaded.
func _rain(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.18)
		lp2 = lerpf(lp2, lp, 0.5)
		buf[i] = lp2 * 0.55
	return _to_wav(_seamless(buf))

## Ambient menu pad. Frequencies are snapped to whole cycles across the loop so
## the seam is inaudible, which a plain noise loop cannot manage.
func _music(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chord := [110.0, 164.8, 220.0, 277.2, 329.6]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in chord.size():
			var f: float = chord[k]
			f = roundf(f * dur) / dur
			var detune := 1.0 + 0.0016 * float(k)
			v += sin(TAU * f * detune * t) * (0.34 - 0.04 * float(k))
		# slow swell so the pad breathes instead of sitting flat
		var swell := 0.72 + 0.28 * sin(TAU * t / dur)
		buf[i] = v * swell * 0.32
	return _to_wav(buf)

## Equal-power crossfade of the tail into the head, for seamless noise loops.
func _seamless(buf: PackedFloat32Array) -> PackedFloat32Array:
	var fade := int(0.08 * RATE)
	for i in fade:
		var a := float(i) / float(fade)
		var tail := buf[buf.size() - fade + i]
		buf[i] = buf[i] * a + tail * (1.0 - a)
	return buf
