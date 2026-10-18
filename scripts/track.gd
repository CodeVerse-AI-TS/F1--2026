class_name Track
extends Node3D
## Procedural Monaco-style street circuit: road, barriers, kerbs, start gantry,
## harbour, buildings and a speed profile for the ghost car.

const HALF_W := 7.5
const WALL_H := 1.1
const WALL_T := 0.7
const STEP := 2.0

const POINTS := [
	Vector3(0, 0, 0), Vector3(0, 0, -260), Vector3(-40, 1, -335), Vector3(-140, 6, -365),
	Vector3(-260, 10, -325), Vector3(-330, 10, -245), Vector3(-295, 8, -175), Vector3(-360, 5, -110),
	Vector3(-420, 2, -40), Vector3(-405, 0, 60), Vector3(-335, 0, 112), Vector3(-300, 0, 88),
	Vector3(-262, 0, 128), Vector3(-150, 0, 160), Vector3(-92, 0, 118), Vector3(-58, 0, 168),
	Vector3(-8, 0, 120),
]

var curve := Curve3D.new()
var length := 0.0
var count := 0
var seg := 2.0
var ideal_time := 60.0
var pts := PackedVector3Array()
var rights := PackedVector3Array()
var tans := PackedVector3Array()
var _time_at := PackedFloat32Array()
## DRS zones as track offsets (metres): {"detect", "start", "end"}. start may sit after the line.
var drs_zones: Array[Dictionary] = []
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 1979
	_build_curve()
	_sample()
	_body = StaticBody3D.new()
	add_child(_body)
	_build_road()
	_build_walls()
	_build_kerbs_and_lines()
	_build_start()
	_build_drs()
	_build_world()
	_build_speed_profile()

# ---------- curve helpers ----------

func _build_curve() -> void:
	var n := POINTS.size()
	for i in n + 1:
		var p: Vector3 = POINTS[i % n]
		var prev: Vector3 = POINTS[(i - 1 + n) % n]
		var nxt: Vector3 = POINTS[(i + 1) % n]
		var h := (nxt - prev) / 5.0
		curve.add_point(p, -h, h)
	curve.bake_interval = 0.5
	length = curve.get_baked_length()

func sample_pos(off: float) -> Vector3:
	return curve.sample_baked(fposmod(off, length), true)

func sample_tangent(off: float) -> Vector3:
	return (sample_pos(off + 1.5) - sample_pos(off - 1.5)).normalized()

func get_xform(off: float) -> Transform3D:
	var p := sample_pos(off)
	var t := sample_tangent(off)
	var tf := Vector3(t.x, 0.0, t.z).normalized()
	return Transform3D(Basis.looking_at(tf, Vector3.UP), p)

func closest_offset(world_pos: Vector3) -> float:
	return curve.get_closest_offset(world_pos - global_position)

func _sample() -> void:
	count = int(length / STEP)
	seg = length / count
	for i in count:
		var off := i * seg
		var t := sample_tangent(off)
		pts.append(sample_pos(off))
		tans.append(t)
		rights.append(t.cross(Vector3.UP).normalized())

# ---------- mesh helpers ----------

func _quad(st: SurfaceTool, v: Array, uv: Array, n: Vector3) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	if (b - a).cross(c - a).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k in order:
		st.set_normal(n)
		st.set_uv(uv[k])
		st.add_vertex(v[k])

func _add_mesh(mesh: Mesh, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _add_collision(mesh: ArrayMesh, backface: bool) -> void:
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = backface
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_body.add_child(cs)

func _stripe_mat(a: Color, b: Color, period: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/stripe.gdshader")
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("period", period)
	return m

# ---------- track geometry ----------

func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		var n := rights[i].cross(tans[i]).normalized()
		var a := pts[i] - rights[i] * HALF_W
		var b := pts[j] - rights[j] * HALF_W
		var c := pts[j] + rights[j] * HALF_W
		var d := pts[i] + rights[i] * HALF_W
		var u0 := i * seg
		var u1 := u0 + seg
		_quad(st, [a, b, c, d], [Vector2(0, u0), Vector2(0, u1), Vector2(1, u1), Vector2(1, u0)], n)
	var mesh := st.commit()
	_add_mesh(mesh, load("res://starter/mat-urban/asphalt_triplanar.tres"))
	_add_collision(mesh, false)

func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		for i in count:
			var j := (i + 1) % count
			var ri: Vector3 = rights[i] * s
			var rj: Vector3 = rights[j] * s
			var ii := pts[i] + ri * HALF_W
			var ij := pts[j] + rj * HALF_W
			var oi := pts[i] + ri * (HALF_W + WALL_T)
			var oj := pts[j] + rj * (HALF_W + WALL_T)
			var ti := pts[i].y + WALL_H
			var tj := pts[j].y + WALL_H
			var u0 := i * seg
			var u1 := u0 + seg
			var uv := [Vector2(0, u0), Vector2(1, u0), Vector2(1, u1), Vector2(0, u1)]
			var ib_i := Vector3(ii.x, -1.5, ii.z)
			var ib_j := Vector3(ij.x, -1.5, ij.z)
			var it_i := Vector3(ii.x, ti, ii.z)
			var it_j := Vector3(ij.x, tj, ij.z)
			var ot_i := Vector3(oi.x, ti, oi.z)
			var ot_j := Vector3(oj.x, tj, oj.z)
			var ob_i := Vector3(oi.x, -1.5, oi.z)
			var ob_j := Vector3(oj.x, -1.5, oj.z)
			_quad(st, [ib_i, it_i, it_j, ib_j], uv, -ri)
			_quad(st, [it_i, ot_i, ot_j, it_j], uv, Vector3.UP)
			_quad(st, [ob_i, ot_i, ot_j, ob_j], uv, ri)
			# red/white painted band on the inner face
			var inset_i := -ri * 0.02
			var inset_j := -rj * 0.02
			var bb_i := Vector3(ii.x, ti - 0.45, ii.z) + inset_i
			var bb_j := Vector3(ij.x, tj - 0.45, ij.z) + inset_j
			_quad(band, [bb_i, it_i + inset_i, it_j + inset_j, bb_j], uv, -ri)
	var mesh := st.commit()
	_add_mesh(mesh, load("res://starter/mat-urban/concrete_triplanar.tres"))
	_add_collision(mesh, true)
	_add_mesh(band.commit(), _stripe_mat(Color(0.75, 0.05, 0.05), Color(0.92, 0.92, 0.9), 3.0))

func _build_kerbs_and_lines() -> void:
	var kerb := SurfaceTool.new()
	kerb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var line := SurfaceTool.new()
	line.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		var t0 := tans[(i - 3 + count) % count]
		var t1 := tans[(i + 3) % count]
		var bend := absf(Vector2(t0.x, t0.z).angle_to(Vector2(t1.x, t1.z)))
		var n := rights[i].cross(tans[i]).normalized()
		var u0 := i * seg
		var u1 := u0 + seg
		var uv := [Vector2(0, u0), Vector2(0, u1), Vector2(1, u1), Vector2(1, u0)]
		for s in [-1.0, 1.0]:
			var ri: Vector3 = rights[i] * s
			var rj: Vector3 = rights[j] * s
			var up := Vector3(0, 0.03, 0)
			if bend > 0.12:
				_quad(kerb, [pts[i] + ri * HALF_W + up, pts[j] + rj * HALF_W + up,
					pts[j] + rj * (HALF_W - 1.3) + up, pts[i] + ri * (HALF_W - 1.3) + up], uv, n)
			var lu := Vector3(0, 0.02, 0)
			_quad(line, [pts[i] + ri * (HALF_W - 1.5) + lu, pts[j] + rj * (HALF_W - 1.5) + lu,
				pts[j] + rj * (HALF_W - 1.75) + lu, pts[i] + ri * (HALF_W - 1.75) + lu], uv, n)
	_add_mesh(kerb.commit(), _stripe_mat(Color(0.8, 0.06, 0.05), Color(0.95, 0.95, 0.92), 1.5), false)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.9, 0.9, 0.86)
	lm.roughness = 0.6
	_add_mesh(line.commit(), lm, false)

func _build_start() -> void:
	var root := Node3D.new()
	add_child(root)
	root.transform = get_xform(0.0)
	# chequered line
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.035
	_quad(st, [Vector3(-HALF_W, y, 1.5), Vector3(-HALF_W, y, -1.5), Vector3(HALF_W, y, -1.5), Vector3(HALF_W, y, 1.5)],
		[Vector2(0, 3), Vector2(0, 0), Vector2(HALF_W * 2, 0), Vector2(HALF_W * 2, 3)], Vector3.UP)
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/checker.gdshader")
	var line := MeshInstance3D.new()
	line.mesh = st.commit()
	line.material_override = cm
	root.add_child(line)
	# gantry
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.08, 0.08, 0.09)
	steel.metallic = 0.7
	steel.roughness = 0.35
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.6, 8.5, 0.6), Vector3(s * (HALF_W + 1.4), 4.25, 0), steel)
	_box(root, Vector3(HALF_W * 2 + 3.4, 1.4, 0.9), Vector3(0, 8.0, 0), steel)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.2, 0.0, 0.0)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.08, 0.05)
	red.emission_energy_multiplier = 3.0
	for k in 5:
		var sph := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		sph.mesh = sm
		sph.material_override = red
		sph.position = Vector3(-2.0 + k * 1.0, 7.0, 0.3)
		root.add_child(sph)
	var label := Label3D.new()
	label.text = "APEX RUSH  -  MONTE CARLO"
	label.font_size = 160
	label.pixel_size = 0.006
	label.outline_size = 0
	label.modulate = Color(1.0, 0.82, 0.45)
	label.position = Vector3(0, 8.0, 0.47)
	label.shaded = false
	root.add_child(label)

## Main straight DRS zone: detection before the last corner exit, activation after the line.
func _build_drs() -> void:
	var o1 := curve.get_closest_offset(POINTS[1])
	var o16 := curve.get_closest_offset(POINTS[16])
	drs_zones.append({"detect": fposmod(o16 - 20.0, length), "start": 35.0, "end": o1 - 45.0})
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	var green := Color(0.25, 1.0, 0.35)
	for z in drs_zones:
		# detection line painted across the road
		var dx := get_xform(z["detect"])
		var line := _box(self, Vector3(HALF_W * 2.0, 0.02, 0.5), Vector3.ZERO, white)
		line.global_transform = dx.translated_local(Vector3(0, 0.03, 0))
		_drs_board(dx, "DRS DETECTION", Color(1, 1, 1))
		_drs_board(get_xform(z["start"]), "DRS", green)
		_drs_board(get_xform(z["end"]), "DRS END", Color(1.0, 0.4, 0.3))

func _drs_board(xf: Transform3D, text: String, col: Color) -> void:
	for s in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 96
		l.pixel_size = 0.01
		l.modulate = col
		l.outline_size = 12
		l.shaded = false
		add_child(l)
		l.global_transform = xf.translated_local(Vector3(s * (HALF_W + 0.4), WALL_H + 1.2, 0))

## Ideal-lap time (seconds) at which the speed profile reaches this offset.
func time_at_offset(off: float) -> float:
	var x := fposmod(off, length) / seg
	var i := clampi(int(x), 0, count - 1)
	return lerpf(_time_at[i], _time_at[i + 1], x - i)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# ---------- surroundings ----------

func _build_world() -> void:
	# ground (pavement) + collision floor
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 1390)
	ground.mesh = pm
	ground.material_override = load("res://starter/mat-stone-brick/cobblestone_triplanar.tres")
	ground.position = Vector3(0, -0.08, -505)
	add_child(ground)
	var wb := CollisionShape3D.new()
	var wbs := WorldBoundaryShape3D.new()
	wb.shape = wbs
	wb.position = Vector3(0, -0.08, 0)
	_body.add_child(wb)
	# harbour water and quay
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(2400, 1100)
	wm.subdivide_width = 120
	wm.subdivide_depth = 60
	water.mesh = wm
	water.material_override = load("res://starter/mat-liquid-glass/water_ocean.tres")
	water.position = Vector3(0, -1.2, 740)
	add_child(water)
	_box(self, Vector3(2400, 2.2, 4), Vector3(0, -1.15, 192), load("res://starter/mat-stone-brick/stone_blocks_triplanar.tres"))
	_build_yachts()
	_build_buildings()
	_build_lamps()
	_build_hills()

func _build_yachts() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.93)
	white.roughness = 0.25
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.05, 0.08)
	glass.metallic = 0.9
	glass.roughness = 0.05
	for k in 16:
		var y := Node3D.new()
		add_child(y)
		y.position = Vector3(_rng.randf_range(-520, 120), -1.0, _rng.randf_range(225, 420))
		y.rotation.y = _rng.randf_range(-0.3, 0.3) + (PI * 0.5 if k % 3 == 0 else 0.0)
		var l := _rng.randf_range(16, 34)
		_box(y, Vector3(l * 0.24, 1.8, l), Vector3(0, 0.6, 0), white)
		_box(y, Vector3(l * 0.18, 1.6, l * 0.45), Vector3(0, 2.2, l * 0.05), white)
		_box(y, Vector3(l * 0.185, 0.6, l * 0.4), Vector3(0, 2.3, l * 0.05), glass)
		if l > 26:
			_box(y, Vector3(l * 0.13, 1.2, l * 0.25), Vector3(0, 3.5, l * 0.1), white)

func _build_buildings() -> void:
	var shader: Shader = load("res://shaders/building.gdshader")
	var palette := [Color(0.93, 0.86, 0.72), Color(0.86, 0.66, 0.45), Color(0.9, 0.62, 0.52),
		Color(0.95, 0.9, 0.78), Color(0.88, 0.78, 0.55), Color(0.8, 0.7, 0.62)]
	var mats: Array[ShaderMaterial] = []
	for k in palette.size():
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("wall_color", palette[k])
		m.set_shader_parameter("seed", float(k) * 3.1)
		mats.append(m)
	var box := BoxMesh.new()
	for i in range(0, count, 11):
		for s in [-1.0, 1.0]:
			var w := _rng.randf_range(14, 26)
			var d := _rng.randf_range(12, 22)
			var h := _rng.randf_range(14, 42) + pts[i].y
			var r: Vector3 = rights[i] * s
			r.y = 0
			r = r.normalized()
			var gap := _rng.randf_range(4.0, 9.0)
			var c := pts[i] + r * (HALF_W + WALL_T + gap + d * 0.5)
			c.y = 0
			if c.z + maxf(w, d) * 0.5 > 182.0:
				continue
			var cp := curve.get_closest_point(c - global_position)
			var clear := Vector2(cp.x - c.x, cp.z - c.z).length()
			if clear < maxf(w, d) * 0.72 + HALF_W + 2.0:
				continue
			var tf := Vector3(tans[i].x, 0, tans[i].z).normalized()
			var mi := MeshInstance3D.new()
			mi.mesh = box
			mi.material_override = mats[_rng.randi() % mats.size()]
			mi.transform = Transform3D(Basis.looking_at(tf, Vector3.UP) * Basis.from_scale(Vector3(w, h, d)),
				c + Vector3(0, h * 0.5 - 0.5, 0))
			add_child(mi)

func _build_lamps() -> void:
	var lamp: PackedScene = load("res://assets/library/racing-realistic/modular-city-road-pack-game-ready-cylinder-14.glb")
	if lamp == null:
		return
	for i in range(0, count, 22):
		var s := 1.0 if (i / 22) % 2 == 0 else -1.0
		var r: Vector3 = rights[i] * s
		r.y = 0
		r = r.normalized()
		var inst: Node3D = lamp.instantiate()
		add_child(inst)
		var xa := -r
		var za := xa.cross(Vector3.UP)
		inst.transform = Transform3D(Basis(xa, Vector3.UP, za).scaled(Vector3.ONE * 3.2),
			pts[i] + r * (HALF_W + WALL_T + 1.0))

func _build_hills() -> void:
	var rock: Material = load("res://starter/mat-stone-brick/rock_triplanar.tres")
	var spots := [
		[Vector3(-450, -40, -1050), Vector3(520, 260, 260)],
		[Vector3(250, -50, -1120), Vector3(420, 200, 240)],
		[Vector3(-1050, -40, -650), Vector3(260, 230, 520)],
		[Vector3(-1100, -40, -50), Vector3(240, 170, 380)],
		[Vector3(700, -60, -800), Vector3(300, 180, 400)],
	]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	for sp in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = rock
		mi.position = sp[0]
		mi.scale = sp[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

# ---------- ghost speed profile ----------

func _build_speed_profile() -> void:
	var v := PackedFloat32Array()
	v.resize(count)
	for i in count:
		var t0 := tans[(i - 4 + count) % count]
		var t1 := tans[(i + 4) % count]
		var ang := absf(Vector2(t0.x, t0.z).angle_to(Vector2(t1.x, t1.z)))
		var k := ang / (8.0 * seg)
		v[i] = minf(84.0, sqrt(30.0 / maxf(k, 0.00001)))
	for _p in 2:
		for i in count:
			var p := (i - 1 + count) % count
			v[i] = minf(v[i], sqrt(v[p] * v[p] + 2.0 * 14.0 * seg))
	for _p in 2:
		for ii in count:
			var i := count - 1 - ii
			var nx := (i + 1) % count
			v[i] = minf(v[i], sqrt(v[nx] * v[nx] + 2.0 * 35.0 * seg))
	_time_at.resize(count + 1)
	_time_at[0] = 0.0
	for i in count:
		_time_at[i + 1] = _time_at[i] + seg / maxf(v[i], 5.0)
	ideal_time = _time_at[count]

func offset_at_time(t: float) -> float:
	t = fposmod(t, ideal_time)
	var lo := 0
	var hi := count
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _time_at[mid] <= t:
			lo = mid
		else:
			hi = mid
	var f := (t - _time_at[lo]) / maxf(_time_at[lo + 1] - _time_at[lo], 0.0001)
	return (lo + f) * seg
