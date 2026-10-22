class_name CarModel
extends Node3D
## Procedural modern F1 car (forward = -Z, ground at y = 0).
## Body parts hang off _chassis (bobs and pitches); wheels stay on the root.
## Animated: wheel spin, steering, suspension bob/pitch, DRS flap, brake disc glow, floor sparks.

@export var bob_amount := 0.006
@export var pitch_brake := 0.016
@export var pitch_accel := 0.008
@export var drs_closed_deg := -16.0
@export var drs_open_deg := 38.0

var ghost := false
var wheels: Array[Node3D] = []
var front_pivots: Array[Node3D] = []
var glow_mat: StandardMaterial3D
var boost_light: OmniLight3D

var _chassis: Node3D
var _drs_pivot: Node3D
var _drs_amount := 0.0
var _drs_target := 0.0
var _brake_heat := 0.0
var _t := 0.0
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _heat_haze: GPUParticles3D
var _labels: Array[Label3D] = []

var _body: StandardMaterial3D
var _accent: StandardMaterial3D
var _carbon: StandardMaterial3D
var _tyre: StandardMaterial3D
var _compound: StandardMaterial3D
var _rim: StandardMaterial3D
var _disc: StandardMaterial3D
var _dark: StandardMaterial3D
var _helmet: StandardMaterial3D
var _rain: StandardMaterial3D

var _mfd_gear: Label3D
var _mfd_speed: Label3D
var _shift_leds: Array[MeshInstance3D] = []
var _led_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	_make_materials()
	_chassis = Node3D.new()
	add_child(_chassis)
	_build_body()
	_build_wings()
	_build_wheels()
	if not ghost:
		_build_livery_labels()
		_build_sparks()
		_build_tyre_smoke()
		_build_exhaust_haze()
		boost_light = OmniLight3D.new()
		boost_light.light_color = Color(1.0, 0.7, 0.3)
		boost_light.omni_range = 6.0
		boost_light.light_energy = 0.0
		boost_light.position = Vector3(0, 0.6, 0.4)
		add_child(boost_light)

# ---------- materials ----------

func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(c * 0.3, 0.5, 0.0)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _make_materials() -> void:
	_body = _mat(Color(0.025, 0.025, 0.028), 0.62, 0.15)
	_accent = _mat(Color(0.6, 0.45, 0.15), 0.45, 0.3)
	_carbon = _mat(Color(0.04, 0.04, 0.045), 0.38, 0.3)
	_tyre = _mat(Color(0.045, 0.045, 0.045), 0.92, 0.0)
	_compound = _mat(Color(0.9, 0.1, 0.08), 0.6, 0.0)
	_rim = _mat(Color(0.12, 0.11, 0.1), 0.3, 0.85)
	_disc = _emissive(Color(1.0, 0.35, 0.05), 0.0)
	_disc.albedo_color = Color(0.15, 0.13, 0.12)
	_dark = _mat(Color(0.0, 0.0, 0.0), 1.0, 0.0)
	_helmet = _mat(Color(0.1, 0.1, 0.11), 0.2, 0.4)
	glow_mat = _emissive(Color(1.0, 0.68, 0.22), 0.6)
	_rain = _emissive(Color(1.0, 0.05, 0.03), 2.5)
	if ghost:
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.45, 0.85, 1.0, 0.28)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.emission_enabled = true
		g.emission = Color(0.3, 0.7, 1.0)
		for k in ["_body", "_accent", "_carbon", "_tyre", "_compound", "_rim", "_disc", "_dark", "_helmet", "_rain"]:
			set(k, g)
		glow_mat = g

# ---------- mesh helpers ----------

func _part(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _chassis).add_child(mi)
	return mi

func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _part(b, pos, mat, parent, rot_deg)

func _cyl(top_r: float, bot_r: float, h: float, pos: Vector3, rot_deg: Vector3, mat: Material, parent: Node3D = null, scl := Vector3.ONE) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.radial_segments = 28
	return _part(c, pos, mat, parent, rot_deg, scl)

# ---------- build ----------

func _build_body() -> void:
	# floor with edge wings and plank
	_box(Vector3(1.6, 0.05, 3.9), Vector3(0, 0.08, 0.35), _carbon)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.05, 0.05, 3.0), Vector3(s * 0.8, 0.11, 0.45), _carbon, Vector3(0, 0, s * 20.0))
	_box(Vector3(0.3, 0.02, 3.0), Vector3(0, 0.045, 0.3), _rim)
	# survival cell and nose
	_box(Vector3(0.75, 0.48, 2.4), Vector3(0, 0.42, -0.3), _body)
	_cyl(0.08, 0.3, 1.9, Vector3(0, 0.33, -2.45), Vector3(-90, 0, 0), _body, null, Vector3(1, 1, 0.5))
	_box(Vector3(0.18, 0.05, 1.3), Vector3(0, 0.46, -2.0), _accent, Vector3(-6, 0, 0))
	# sidepods: upper body, undercut, inlet, tapering rear, livery stripe, glow strip
	for s in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.4, 1.5), Vector3(s * 0.6, 0.44, 0.15), _body)
		_box(Vector3(0.42, 0.16, 1.3), Vector3(s * 0.58, 0.2, 0.25), _carbon)
		_box(Vector3(0.4, 0.26, 0.04), Vector3(s * 0.6, 0.48, -0.61), _dark)
		_cyl(0.1, 0.24, 0.9, Vector3(s * 0.52, 0.42, 1.25), Vector3(90, 0, 0), _body, null, Vector3(1, 1, 0.85))
		_box(Vector3(0.5, 0.05, 1.45), Vector3(s * 0.6, 0.645, 0.15), _accent)
		_box(Vector3(0.02, 0.03, 1.4), Vector3(s * 0.86, 0.6, 0.15), glow_mat)
	# engine cover, shark fin, tail, airbox
	_box(Vector3(0.5, 0.45, 1.6), Vector3(0, 0.78, 0.55), _body)
	_box(Vector3(0.03, 0.36, 1.3), Vector3(0, 1.08, 0.95), _body)
	_box(Vector3(0.035, 0.06, 1.3), Vector3(0, 1.24, 0.95), _accent)
	_cyl(0.07, 0.26, 1.1, Vector3(0, 0.6, 1.85), Vector3(90, 0, 0), _body, null, Vector3(1, 1, 0.8))
	_box(Vector3(0.3, 0.32, 0.45), Vector3(0, 1.0, 0.0), _body)
	_box(Vector3(0.2, 0.18, 0.04), Vector3(0, 1.05, -0.23), _dark)
	# T-cam pod on the roll hoop: matte carbon housing with a dark glass lens
	_box(Vector3(0.08, 0.05, 0.14), Vector3(0, 1.18, -0.08), _carbon)
	_box(Vector3(0.03, 0.03, 0.02), Vector3(0, 1.18, -0.155), _dark)
	# cockpit, driver, steering wheel, halo
	_box(Vector3(0.5, 0.06, 0.7), Vector3(0, 0.68, -0.55), _dark)
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	_part(hs, Vector3(0, 0.82, -0.45), _helmet)
	_box(Vector3(0.18, 0.04, 0.03), Vector3(0, 0.84, -0.58), _dark)
	# Steering wheel and active MFD telemetry display
	_box(Vector3(0.26, 0.12, 0.03), Vector3(0, 0.72, -0.82), _carbon, Vector3(-30, 0, 0))
	_box(Vector3(0.14, 0.07, 0.01), Vector3(0, 0.725, -0.805), _dark, Vector3(-30, 0, 0))
	_mfd_gear = Label3D.new()
	_mfd_gear.text = "1"
	_mfd_gear.font_size = 54
	_mfd_gear.pixel_size = 0.0015
	_mfd_gear.modulate = Color(1.0, 0.92, 0.35)
	_mfd_gear.outline_size = 0
	_mfd_gear.shaded = false
	_mfd_gear.position = Vector3(-0.026, 0.725, -0.795)
	_mfd_gear.rotation_degrees = Vector3(-30, 0, 0)
	_chassis.add_child(_mfd_gear)

	_mfd_speed = Label3D.new()
	_mfd_speed.text = "0"
	_mfd_speed.font_size = 38
	_mfd_speed.pixel_size = 0.0013
	_mfd_speed.modulate = Color(0.85, 0.95, 1.0)
	_mfd_speed.outline_size = 0
	_mfd_speed.shaded = false
	_mfd_speed.position = Vector3(0.026, 0.725, -0.795)
	_mfd_speed.rotation_degrees = Vector3(-30, 0, 0)
	_chassis.add_child(_mfd_speed)

	var led_colors := [Color(0.2, 1.0, 0.3), Color(0.2, 1.0, 0.3), Color(1.0, 0.15, 0.1), Color(1.0, 0.15, 0.1), Color(0.2, 0.55, 1.0)]
	for k in 5:
		var m := StandardMaterial3D.new()
		m.albedo_color = led_colors[k] * 0.25
		m.emission_enabled = true
		m.emission = led_colors[k]
		m.emission_energy_multiplier = 0.0
		_led_mats.append(m)
		var led := _box(Vector3(0.016, 0.008, 0.008), Vector3(-0.04 + k * 0.02, 0.765, -0.785), m, Vector3(-30, 0, 0))
		_shift_leds.append(led)
	_box(Vector3(0.06, 0.25, 0.06), Vector3(0, 0.8, -1.0), _carbon)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.3
	tor.outer_radius = 0.35
	_part(tor, Vector3(0, 0.95, -0.55), _carbon, null, Vector3.ZERO, Vector3(1, 1, 1.3))
	# diffuser and rear light
	_box(Vector3(1.0, 0.22, 0.45), Vector3(0, 0.18, 2.35), _carbon, Vector3(-12, 0, 0))
	_box(Vector3(0.14, 0.08, 0.03), Vector3(0, 0.45, 2.6), _rain)

func _build_wings() -> void:
	# front wing: mainplane, three flaps (top flap in livery accent), endplates, pylons
	_box(Vector3(2.0, 0.035, 0.5), Vector3(0, 0.1, -3.15), _carbon)
	for k in 3:
		_box(Vector3(1.9 - 0.12 * k, 0.025, 0.22), Vector3(0, 0.14 + 0.05 * k, -3.05 + 0.08 * k),
			_accent if k == 2 else _carbon, Vector3(10 + 8 * k, 0, 0))
	for s in [-1.0, 1.0]:
		_box(Vector3(0.03, 0.3, 0.7), Vector3(s * 1.0, 0.2, -3.1), _body)
		_box(Vector3(0.04, 0.2, 0.3), Vector3(s * 0.15, 0.2, -3.0), _carbon)
	# rear wing: endplates, mainplane, DRS flap on a pivot at its leading edge, beam wing, pillar
	for s in [-1.0, 1.0]:
		_box(Vector3(0.03, 0.6, 0.75), Vector3(s * 0.52, 0.85, 2.5), _body)
	_box(Vector3(1.02, 0.05, 0.35), Vector3(0, 0.95, 2.5), _carbon)
	_drs_pivot = Node3D.new()
	_drs_pivot.position = Vector3(0, 1.04, 2.42)
	_drs_pivot.rotation_degrees.x = drs_closed_deg
	_chassis.add_child(_drs_pivot)
	_box(Vector3(1.0, 0.035, 0.3), Vector3(0, 0, 0.15), _accent, Vector3.ZERO, _drs_pivot)
	_box(Vector3(0.9, 0.03, 0.2), Vector3(0, 0.45, 2.55), _carbon)
	_box(Vector3(0.05, 0.5, 0.1), Vector3(0, 0.72, 2.38), _carbon)

func _build_wheels() -> void:
	var corners := [[Vector3(-0.88, 0.34, -1.85), true], [Vector3(0.88, 0.34, -1.85), true],
		[Vector3(-0.85, 0.36, 1.55), false], [Vector3(0.85, 0.36, 1.55), false]]
	for c in corners:
		var p: Vector3 = c[0]
		var front: bool = c[1]
		var side := signf(p.x)
		var pivot := Node3D.new()
		pivot.position = p
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var r := 0.34 if front else 0.36
		var w := 0.36 if front else 0.44
		_cyl(r, r, w, Vector3.ZERO, Vector3(0, 0, 90), _tyre, spin)
		# compound stripe on the outer sidewall
		var ring := TorusMesh.new()
		ring.inner_radius = r * 0.72
		ring.outer_radius = r * 0.8
		ring.rings = 32
		_part(ring, Vector3(side * (w * 0.5 + 0.003), 0, 0), _compound, spin, Vector3(0, 0, 90))
		_cyl(r * 0.6, r * 0.6, w + 0.02, Vector3.ZERO, Vector3(0, 0, 90), _rim, spin)
		_box(Vector3(w + 0.03, r * 1.05, 0.05), Vector3.ZERO, glow_mat if not ghost else _rim, Vector3.ZERO, spin)
		# brake disc on the inboard side (does not spin visually, glows when braking hard)
		_cyl(r * 0.45, r * 0.45, 0.04, Vector3(-side * (w * 0.5 + 0.03), 0, 0), Vector3(0, 0, 90), _disc, pivot)
		wheels.append(spin)
		if front:
			front_pivots.append(pivot)
		var arm_x := p.x * 0.55
		_box(Vector3(absf(p.x) * 0.9, 0.03, 0.05), Vector3(arm_x, p.y + 0.06, p.z - 0.1), _carbon, Vector3.ZERO, self)
		_box(Vector3(absf(p.x) * 0.9, 0.03, 0.05), Vector3(arm_x, p.y - 0.08, p.z + 0.1), _carbon, Vector3.ZERO, self)

func _label(text: String, pos: Vector3, rot_deg: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 6
	l.position = pos
	l.rotation_degrees = rot_deg
	l.double_sided = false
	_chassis.add_child(l)
	_labels.append(l)
	return l

func _build_livery_labels() -> void:
	for s in [-1.0, 1.0]:
		_label("SPONSOR", Vector3(s * 0.86, 0.43, 0.15), Vector3(0, s * 90.0, 0), 44)
		_label("0", Vector3(s * 0.02, 1.02, 1.0), Vector3(0, s * 90.0, 0), 70)
	_label("0", Vector3(0, 0.49, -1.75), Vector3(-90, 0, 0), 56)

func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.amount = 90
	_sparks.lifetime = 0.35
	_sparks.emitting = false
	_sparks.local_coords = false
	_sparks.position = Vector3(0, 0.04, 1.2)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.25, 1)
	pm.spread = 28.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -14, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.01, 0.6)
	_sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1.0, 0.75, 0.35)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.55, 0.15)
	sm.emission_energy_multiplier = 6.0
	q.material = sm
	_sparks.draw_pass_1 = q
	_chassis.add_child(_sparks)

func _build_tyre_smoke() -> void:
	_smoke = GPUParticles3D.new()
	_smoke.amount = 40
	_smoke.lifetime = 0.45
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.position = Vector3(0, 0.1, -1.2)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.35, 1.0)
	pm.spread = 30.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 2.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.85, 0.06, 0.35)
	_smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.92, 0.92, 0.95, 0.22)
	q.material = sm
	_smoke.draw_pass_1 = q
	_chassis.add_child(_smoke)

func _build_exhaust_haze() -> void:
	_heat_haze = GPUParticles3D.new()
	_heat_haze.amount = 25
	_heat_haze.lifetime = 0.32
	_heat_haze.emitting = false
	_heat_haze.local_coords = false
	_heat_haze.position = Vector3(0, 0.48, 2.45)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.25, 1.0)
	pm.spread = 15.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, 2.5, 0)
	pm.scale_min = 0.2
	pm.scale_max = 0.75
	_heat_haze.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 0.25)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1.0, 0.95, 0.88, 0.08)
	q.material = sm
	_heat_haze.draw_pass_1 = q
	_chassis.add_child(_heat_haze)

# ---------- public API ----------

## Team livery: primary body colour, secondary stripes/flaps, accent glow, sponsor text and number.
func set_livery(team: Dictionary) -> void:
	if ghost:
		return
	set_colors(team.get("color", Color.BLACK), team.get("accent", Color(1, 0.7, 0.2)))
	_accent.albedo_color = team.get("secondary", Color(0.6, 0.45, 0.15))
	var sponsor := String(team.get("sponsor", "APEX"))
	var number := str(team.get("number", 1))
	for l in _labels:
		l.text = sponsor if l.font_size == 44 else number
		l.modulate = team.get("accent", Color.WHITE)

func set_colors(body: Color, accent: Color) -> void:
	if ghost:
		return
	_body.albedo_color = body
	glow_mat.emission = accent
	boost_light.light_color = accent

func set_compound_color(c: Color) -> void:
	if not ghost:
		_compound.albedo_color = c

func set_drs(open: bool) -> void:
	_drs_target = 1.0 if open else 0.0

func update_visual(delta: float, speed: float, steer: float, boost_amount: float,
		brake := 0.0, throttle := 0.0, sparks := false, p_gear := 1) -> void:
	_t += delta
	for w in wheels:
		w.rotate_x(-speed / 0.35 * delta)
	for p in front_pivots:
		p.rotation.y = steer * 0.38
	var ratio := clampf(absf(speed) / 88.0, 0.0, 1.2)
	# MFD live gear, speed, and shift lights
	if _mfd_gear:
		_mfd_gear.text = str(clampi(p_gear, 1, 8))
	if _mfd_speed:
		_mfd_speed.text = str(int(round(absf(speed) * 3.6)))
	var rev_pct := clampf((absf(speed) / 88.0) * 1.15, 0.0, 1.0)
	for k in _led_mats.size():
		var threshold := float(k + 1) / 5.5
		_led_mats[k].emission_energy_multiplier = 4.5 if rev_pct >= threshold else 0.0
	# suspension: high-frequency bob with speed, nose dive under braking, squat under throttle
	_chassis.position.y = sin(_t * 23.0) * bob_amount * ratio + sin(_t * 7.3) * bob_amount * 0.5 * ratio
	var pitch := -brake * pitch_brake * clampf(ratio * 2.0, 0.0, 1.0) + throttle * pitch_accel * (1.0 - ratio)
	_chassis.rotation.x = lerpf(_chassis.rotation.x, pitch, 1.0 - exp(-8.0 * delta))
	_chassis.rotation.z = lerpf(_chassis.rotation.z, -steer * 0.012 * ratio, 1.0 - exp(-6.0 * delta))
	# DRS flap
	_drs_amount = move_toward(_drs_amount, _drs_target, delta * 5.0)
	_drs_pivot.rotation_degrees.x = lerpf(drs_closed_deg, drs_open_deg, _drs_amount)
	if ghost:
		return
	glow_mat.emission_energy_multiplier = lerpf(0.6, 7.0, boost_amount)
	boost_light.light_energy = boost_amount * 3.5
	# brake discs heat up under hard braking at speed and cool down slowly
	var heat_target := brake * clampf(ratio * 1.5, 0.0, 1.0)
	_brake_heat = move_toward(_brake_heat, heat_target, delta * (2.5 if heat_target > _brake_heat else 0.6))
	_disc.emission_energy_multiplier = _brake_heat * _brake_heat * 8.0
	# rear light flashes under heavy braking
	_rain.emission_energy_multiplier = 6.0 if brake > 0.5 and fmod(_t, 0.2) < 0.1 else 2.5
	_sparks.emitting = sparks
	if _smoke:
		_smoke.emitting = brake > 0.65 and absf(speed) > 18.0
	if _heat_haze:
		_heat_haze.emitting = throttle > 0.15 or boost_amount > 0.05
