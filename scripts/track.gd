class_name Track
extends Node3D
## Builds the circuit from a track data dictionary (GameState.TRACKS): road, barriers,
## kerbs, start gantry, DRS zone, pit lane, and scenery chosen by the track theme
## (street, fast, technical, coast, night). Also exposes the speed profile used by the AI.

const GameState = preload("res://scripts/game_state.gd")

const BASE_HALF := 7.5
const WALL_H := 1.1
const WALL_T := 0.7
const STEP := 2.0

## Fallback centre line (the Monte Carlo street circuit) when no data is supplied.
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
var _speed := PackedFloat32Array()
## DRS zones as track offsets (metres): {"detect", "start", "end"}. start may sit after the line.
var drs_zones: Array[Dictionary] = []
## Pit lane: entry/exit offsets and the pit box where the crew works.
var pit := {"entry": 0.0, "exit": 0.0, "box": 0.0, "side": -1.0, "offset": 8.0}
## Side the pit lane is on (-1 = left of travel) and how long the merge gaps are (metres).
var pit_side := -1.0
var pit_merge := 48.0
## Track data (theme, widths, scenery) and the theme dictionary resolved from it.
var data: Dictionary = {}
var theme: Dictionary = {}
var half_w := 7.5
## Read-only width for scripts written against the old constant (AI, camera, session).
var HALF_W: float:
	get:
		return half_w
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _grass: Material
## Map extents, filled in _build_world and used by the scenery builders.
var _z_limit := 180.0
var _map_center := Vector3.ZERO
var _hi_z := 190.0

func _ready() -> void:
	data = GameState.track() if data.is_empty() else data
	if theme.is_empty():
		theme = GameState.THEMES.get(String(data.get("theme", "street")), GameState.THEMES["street"])
	half_w = float(data.get("half_w", BASE_HALF))
	_rng.seed = int(data.get("seed", 1979))
	_apply_sky()
	_build_curve()
	_sample()
	_body = StaticBody3D.new()
	add_child(_body)
	_plan_pit()
	_build_road()
	_build_walls()
	_build_kerbs_and_lines()
	_build_start()
	_build_drs()
	_build_pit_lane()
	_build_world()
	_build_speed_profile()

## Sky and sun for this theme. The golden-hour look rig duplicates its Environment,
## so the values set here stay with this track's instance.
func _apply_sky() -> void:
	var look := get_parent().get_node_or_null("Look")
	if look == null or not look.has_method("get_environment"):
		return
	var env: Environment = look.get_environment()
	if env:
		env.background_mode = Environment.BG_COLOR
		env.background_color = theme["sky_top"]
		env.ambient_light_color = theme["ambient"]
		env.ambient_light_energy = float(theme["ambient_energy"])
		env.fog_enabled = true
		env.fog_light_color = theme["haze"]
		env.fog_density = float(theme["fog"])
		env.fog_sky_affect = 1.0
		if String(data.get("theme", "")) == "night":
			env.glow_enabled = true
			env.glow_intensity = 0.55
	var sun := look.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = theme["sun"]
		sun.light_energy = float(theme["sun_energy"])
		sun.shadow_enabled = true

# ---------- curve helpers ----------

func _build_curve() -> void:
	var src: Array = GameState.track_points(data) if not data.is_empty() else POINTS
	var n := src.size()
	for i in n + 1:
		var p: Vector3 = src[i % n]
		var prev: Vector3 = src[(i - 1 + n) % n]
		var nxt: Vector3 = src[(i + 1) % n]
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
		var a := pts[i] - rights[i] * half_w
		var b := pts[j] - rights[j] * half_w
		var c := pts[j] + rights[j] * half_w
		var d := pts[i] + rights[i] * half_w
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
			# the pit side is opened between pit entry and exit so cars can dive in
			if s == pit_side and _in_span(i * seg, float(pit["entry"]), float(pit["exit"])):
				continue
			var j := (i + 1) % count
			var ri: Vector3 = rights[i] * s
			var rj: Vector3 = rights[j] * s
			var ii := pts[i] + ri * half_w
			var ij := pts[j] + rj * half_w
			var oi := pts[i] + ri * (half_w + WALL_T)
			var oj := pts[j] + rj * (half_w + WALL_T)
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
				_quad(kerb, [pts[i] + ri * half_w + up, pts[j] + rj * half_w + up,
					pts[j] + rj * (half_w - 1.3) + up, pts[i] + ri * (half_w - 1.3) + up], uv, n)
			var lu := Vector3(0, 0.02, 0)
			_quad(line, [pts[i] + ri * (half_w - 1.5) + lu, pts[j] + rj * (half_w - 1.5) + lu,
				pts[j] + rj * (half_w - 1.75) + lu, pts[i] + ri * (half_w - 1.75) + lu], uv, n)
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
	_quad(st, [Vector3(-half_w, y, 1.5), Vector3(-half_w, y, -1.5), Vector3(half_w, y, -1.5), Vector3(half_w, y, 1.5)],
		[Vector2(0, 3), Vector2(0, 0), Vector2(half_w * 2, 0), Vector2(half_w * 2, 3)], Vector3.UP)
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
		_box(root, Vector3(0.6, 8.5, 0.6), Vector3(s * (half_w + 1.4), 4.25, 0), steel)
	_box(root, Vector3(half_w * 2 + 3.4, 1.4, 0.9), Vector3(0, 8.0, 0), steel)
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

## DRS zones come from the track data as lap fractions, so every circuit gets its own.
func _build_drs() -> void:
	var zones: Array = data.get("drs", [])
	if zones.is_empty():
		zones = [{"detect": 0.94, "start": 0.03, "end": 0.22}]
	for z in zones:
		var zz: Dictionary = z
		drs_zones.append({
			"detect": fposmod(float(zz.get("detect", 0.94)) * length, length),
			"start": fposmod(float(zz.get("start", 0.03)) * length, length),
			"end": fposmod(float(zz.get("end", 0.22)) * length, length),
		})
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	var green := Color(0.25, 1.0, 0.35)
	for z in drs_zones:
		# detection line painted across the road
		var dx := get_xform(z["detect"])
		var line := _box(self, Vector3(half_w * 2.0, 0.02, 0.5), Vector3.ZERO, white)
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
		l.global_transform = xf.translated_local(Vector3(s * (half_w + 0.4), WALL_H + 1.2, 0))

## Pit lane on the inside of the main straight: parallel apron, pit wall, garages,
## limiter lines at the entry and exit, and a marked pit box.
## Where the pit lane lives for this circuit. Called before the road and walls so the
## barrier on the pit side can be opened exactly across the entry -> exit span.
func _plan_pit() -> void:
	var frac: Dictionary = data.get("pit", {})
	var entry_f := float(frac.get("entry", 0.79))
	var exit_f := float(frac.get("exit", 0.11))
	pit["entry"] = fposmod(entry_f * length, length)
	pit["exit"] = fposmod(exit_f * length, length)
	pit["box"] = fposmod(float(frac.get("box", 0.045)) * length, length)
	pit["side"] = -1.0
	pit_side = -1.0
	pit_merge = 48.0

## True when off lies inside the forward span a -> b (wrapping over the line).
func _in_span(off: float, a: float, b: float) -> bool:
	return fposmod(off - a, length) <= fposmod(b - a, length)

func _build_pit_lane() -> void:
	var half := 3.4                     # pit lane half width
	# inner edge sits on the track edge, so the pit wall is the only separator
	var lane_lat := pit_side * (half_w + half)
	var span := fposmod(pit["exit"] - pit["entry"], length)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(int(span / seg), 1)
	var up := Vector3(0, 0.04, 0)
	for k in steps:
		var o0: float = pit["entry"] + k * seg
		var o1: float = o0 + seg
		var r0 := _right_at(o0)
		var r1 := _right_at(o1)
		var p0 := sample_pos(o0)
		var p1 := sample_pos(o1)
		var a := p0 + r0 * (lane_lat - half) + up
		var b := p1 + r1 * (lane_lat - half) + up
		var c := p1 + r1 * (lane_lat + half) + up
		var d := p0 + r0 * (lane_lat + half) + up
		var u0 := k * seg
		_quad(st, [a, b, c, d], [Vector2(0, u0), Vector2(0, u0 + seg), Vector2(1, u0 + seg), Vector2(1, u0)], Vector3.UP)
	var lane_mesh := st.commit()
	_add_mesh(lane_mesh, load("res://starter/mat-urban/asphalt_triplanar.tres"))
	_add_collision(lane_mesh, false)
	# white lane edge and limiter lines at the entry and exit
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.94, 0.94, 0.92)
	white.roughness = 0.7
	for k in steps:
		var o: float = pit["entry"] + k * seg
		var r := _right_at(o)
		var p := sample_pos(o)
		var e := _box(self, Vector3(0.18, 0.02, seg + 0.1), Vector3.ZERO, white)
		var xa := r
		var za := xa.cross(Vector3.UP)
		e.global_transform = Transform3D(Basis(xa, Vector3.UP, za), p + r * (lane_lat - half + 0.1) + up)
	for o in [pit["entry"], pit["exit"]]:
		var r := _right_at(o)
		var p := sample_pos(o)
		var line := _box(self, Vector3(half * 2.0, 0.02, 0.45), Vector3.ZERO, white)
		line.global_transform = Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), p + r * lane_lat + up)
		_pit_board(p + r * lane_lat, r, "PIT LIMITER 80", Color(1.0, 0.85, 0.3))
	# pit wall, garages and the marked pit box
	var wall_mat := load("res://starter/mat-urban/concrete_triplanar.tres")
	var garage_mat := StandardMaterial3D.new()
	garage_mat.albedo_color = Color(0.1, 0.1, 0.12)
	garage_mat.roughness = 0.5
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.55, 0.55, 0.58)
	door_mat.metallic = 0.4
	door_mat.roughness = 0.3
	var k2 := 0
	while k2 < steps:
		var o: float = pit["entry"] + k2 * seg
		var r := _right_at(o)
		var p := sample_pos(o)
		# pit wall on the track edge, with open merge gaps at both ends of the lane
		var into := fposmod(o - float(pit["entry"]), length)
		var left := span - into
		if into > pit_merge and left > pit_merge:
			var w := _box(self, Vector3(0.45, 1.05, seg * 2.0 + 0.1), Vector3.ZERO, wall_mat)
			var xa2 := r
			w.global_transform = Transform3D(Basis(xa2, Vector3.UP, xa2.cross(Vector3.UP)), p + r * (lane_lat + half) + Vector3(0, 0.5, 0))
		k2 += 2
	var gsteps := maxi(int(span / 18.0), 1)
	for g in gsteps:
		var o: float = pit["entry"] + 9.0 + g * 18.0
		var r := _right_at(o)
		var p := sample_pos(o)
		var gx := r
		var gz := gx.cross(Vector3.UP)
		var base := p + r * (lane_lat - half - 6.0)
		var gar := _box(self, Vector3(12.0, 5.0, 18.0), Vector3.ZERO, garage_mat)
		gar.global_transform = Transform3D(Basis(gx, Vector3.UP, gz), base + Vector3(0, 2.4, 0))
		var door := _box(self, Vector3(0.2, 3.2, 6.0), Vector3.ZERO, door_mat)
		door.global_transform = Transform3D(Basis(gx, Vector3.UP, gz), base + gx * 6.1 + Vector3(0, 1.6, 0))
	# pit box marking and board
	var br := _right_at(pit["box"])
	var bp := sample_pos(pit["box"])
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(1.0, 0.78, 0.15)
	box_mat.emission_enabled = true
	box_mat.emission = Color(1.0, 0.7, 0.1)
	box_mat.emission_energy_multiplier = 0.35
	for s in [-1.0, 1.0]:
		var bar := _box(self, Vector3(half * 2.0, 0.02, 0.22), Vector3.ZERO, box_mat)
		bar.global_transform = Transform3D(Basis(br, Vector3.UP, br.cross(Vector3.UP)), bp + br * lane_lat + up + sample_tangent(pit["box"]).normalized() * s * 3.0)
	_pit_board(bp + br * lane_lat, br, "PIT BOX", Color(1.0, 0.85, 0.2))

	# ---- entry gate: "PIT ENTRY" board over the lane, chevrons painted on the tarmac ----
	var entry: float = pit["entry"]
	var er := _right_at(entry)
	var ep := sample_pos(entry)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.07, 0.07, 0.08)
	steel.metallic = 0.7
	steel.roughness = 0.35
	# two posts either side of the lane and a beam across it
	for s in [-1.0, 1.0]:
		var post := _box(self, Vector3(0.35, 5.0, 0.35), Vector3.ZERO, steel)
		post.global_transform = Transform3D(Basis(er, Vector3.UP, er.cross(Vector3.UP)),
			ep + er * (lane_lat + half * s) + Vector3(0, 2.5, 0))
	var beam := _box(self, Vector3(half * 2.0 + 0.7, 0.5, 0.5), Vector3.ZERO, steel)
	beam.global_transform = Transform3D(Basis(er, Vector3.UP, er.cross(Vector3.UP)),
		ep + er * lane_lat + Vector3(0, 5.0, 0))
	# board text faces back down the straight, so the driver reads it on approach
	_pit_sign(entry, lane_lat, "PIT ENTRY", Color(1.0, 0.82, 0.2), 5.4, 150, -1.0)
	_pit_sign(entry + 1.0, lane_lat, "80", Color(1.0, 1.0, 1.0), 3.6, 90, 0.0)
	# yellow chevrons on the ground funnelling from the track into the lane
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1.0, 0.78, 0.1)
	yellow.emission_enabled = true
	yellow.emission = Color(1.0, 0.68, 0.05)
	yellow.emission_energy_multiplier = 0.45
	for k in 5:
		var o: float = entry + 2.0 + k * 6.0
		var rr := _right_at(o)
		var pp := sample_pos(o)
		var lat := lerpf(lane_lat + half * 0.55, lane_lat, float(k) / 4.0)
		var ch := Transform3D(Basis(rr, Vector3.UP, rr.cross(Vector3.UP)) * Basis(Vector3.UP, 0.6),
			pp + rr * lat + Vector3(0, 0.05, 0))
		var bar1 := _box(self, Vector3(1.9, 0.02, 0.28), Vector3.ZERO, yellow)
		bar1.global_transform = ch.translated_local(Vector3(0, 0, 0))
		var bar2 := _box(self, Vector3(1.9, 0.02, 0.28), Vector3.ZERO, yellow)
		bar2.global_transform = ch.translated_local(Vector3(0, 0, 1.1)) * Transform3D(Basis(Vector3.UP, 1.6), Vector3.ZERO)
	# white merge taper from the track edge into the lane at the entry
	var taper := _box(self, Vector3(half * 0.9, 0.02, 0.3), Vector3.ZERO, white)
	taper.global_transform = Transform3D(Basis(er, Vector3.UP, er.cross(Vector3.UP)) * Basis(Vector3.UP, 0.45),
		ep + er * (lane_lat + half * 0.5) + Vector3(0, 0.04, 0))
	# END OF entry gate

func _right_at(off: float) -> Vector3:
	var t := sample_tangent(off)
	return Vector3(t.x, 0.0, t.z).normalized().cross(Vector3.UP).normalized()

func _pit_board(pos: Vector3, right: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 12
	l.shaded = false
	add_child(l)
	var fwd := right.cross(Vector3.UP).normalized()
	l.global_transform = Transform3D(Basis(right, Vector3.UP, right.cross(Vector3.UP)).scaled(Vector3.ONE), pos + Vector3(0, 3.2, 0))
	l.rotate_y(PI * 0.5)
	l.rotate_x(-PI * 0.5)

## Text board beside or above the lane at this offset. It faces back down the track,
## so a driver approaching in the racing direction can read it.
func _pit_sign(off: float, lat: float, text: String, col: Color, height: float,
		size: int, roll := 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.012
	l.modulate = col
	l.outline_size = 16
	l.shaded = false
	add_child(l)
	var t := sample_tangent(off)
	var fwd := Vector3(t.x, 0.0, t.z).normalized()
	var r := _right_at(off)
	var pos := sample_pos(off) + r * lat + Vector3(0, height, 0)
	l.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	if roll != 0.0:
		l.rotate_z(roll)

## True when this track offset lies inside the pit lane (entry -> exit through the line).
func in_pit_lane(off: float) -> bool:
	var span := fposmod(off - float(pit["entry"]), length)
	return span <= fposmod(float(pit["exit"]) - float(pit["entry"]), length)

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

## Scenery is chosen by the track theme: a street block, an open speedway, an alpine
## park, a dune coast or a floodlit night harbour.
func _build_world() -> void:
	# ground sized to the circuit so every layout is fully covered
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	for p in pts:
		lo = Vector3(minf(lo.x, p.x), 0, minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), 0, maxf(hi.z, p.z))
	var c := (lo + hi) * 0.5
	var span := hi - lo
	var size := Vector2(span.x + 1400.0, span.z + 1400.0)
	_z_limit = hi.z + 60.0
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	ground.mesh = pm
	ground.material_override = _ground_material()
	ground.position = Vector3(c.x, -0.08, c.z)
	add_child(ground)
	var wb := CollisionShape3D.new()
	var wbs := WorldBoundaryShape3D.new()
	wb.shape = wbs
	wb.position = Vector3(0, -0.08, 0)
	_body.add_child(wb)
	if bool(theme.get("harbour", false)):
		# sea beyond the far edge of the circuit, with a stone quay wall
		var water := MeshInstance3D.new()
		var wm := PlaneMesh.new()
		wm.size = Vector2(size.x + 600.0, 1400.0)
		wm.subdivide_width = 120
		wm.subdivide_depth = 60
		water.mesh = wm
		water.material_override = load("res://starter/mat-liquid-glass/water_ocean.tres")
		water.position = Vector3(c.x, -1.2, hi.z + 760.0)
		add_child(water)
		_box(self, Vector3(size.x + 600.0, 2.2, 4), Vector3(c.x, -1.15, hi.z + 192.0),
			load("res://starter/mat-stone-brick/stone_blocks_triplanar.tres"))
		_build_yachts()
	if bool(theme.get("buildings", false)):
		_build_buildings()
	if bool(theme.get("lamps", false)):
		_build_lamps()
	if bool(theme.get("hills", false)):
		_build_hills()
	if int(theme.get("vegetation", 0)) > 0:
		_build_vegetation(int(theme["vegetation"]))
	if bool(theme.get("floodlights", false)):
		_build_floodlights()

## Ground material per theme: duplicate the shared material so the tint stays local.
func _ground_material() -> Material:
	var kind := String(theme.get("ground", "cobblestone"))
	var path := "res://starter/mat-stone-brick/cobblestone_triplanar.tres"
	match kind:
		"grass", "sand":
			path = "res://starter/mat-urban/concrete_triplanar.tres"
		"asphalt":
			path = "res://starter/mat-urban/asphalt_triplanar.tres"
	var m: Material = load(path)
	if m is BaseMaterial3D:
		var dup := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
		dup.albedo_color = theme.get("ground_tint", Color.WHITE)
		return dup
	return m

## Trees or desert scrub along the outside of the circuit, never on the racing surface.
func _build_vegetation(kind: int) -> void:
	var trunk := StandardMaterial3D.new()
	trunk.albedo_color = Color(0.24, 0.17, 0.11)
	trunk.roughness = 0.9
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.42, 0.18) if kind != 3 else Color(0.36, 0.44, 0.24)
	leaf.roughness = 0.85
	var every := 14 if kind == 2 else 20
	for i in range(0, count, every):
		for s in [-1.0, 1.0]:
			if _rng.randf() < 0.35:
				continue
			var r: Vector3 = _right_at(i * seg) * s
			var off := half_w + WALL_T + _rng.randf_range(9.0, 26.0)
			var pos: Vector3 = pts[i] + r * off
			var cp := curve.get_closest_point(pos - global_position)
			if Vector2(cp.x - pos.x, cp.z - pos.z).length() < half_w + 8.0:
				continue
			if kind == 3:
				# desert: low scrub and a few boulders
				var bush := _box(self, Vector3(_rng.randf_range(1.4, 3.0), _rng.randf_range(0.6, 1.4), _rng.randf_range(1.4, 3.0)),
					Vector3.ZERO, leaf)
				bush.global_position = pos + Vector3(0, 0.4, 0)
				bush.rotation.y = _rng.randf() * TAU
				if _rng.randf() < 0.3:
					var rock := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = _rng.randf_range(1.0, 2.4)
					sm.height = sm.radius * 1.4
					rock.mesh = sm
					rock.material_override = load("res://starter/mat-stone-brick/rock_triplanar.tres")
					rock.position = pos + Vector3(_rng.randf_range(-6, 6), 0.3, _rng.randf_range(-6, 6))
					add_child(rock)
			else:
				var h := _rng.randf_range(4.0, 9.0)
				var t := _box(self, Vector3(0.45, h, 0.45), Vector3.ZERO, trunk)
				t.global_position = pos + Vector3(0, h * 0.5, 0)
				var crown := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.2
				cm.bottom_radius = h * 0.34
				cm.height = h * 0.75
				cm.radial_segments = 10
				crown.mesh = cm
				crown.material_override = leaf
				crown.position = pos + Vector3(0, h * 0.95, 0)
				add_child(crown)

## Tall masts with warm heads around a night circuit.
func _build_floodlights() -> void:
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.16, 0.17, 0.2)
	pole.metallic = 0.6
	pole.roughness = 0.4
	var head := StandardMaterial3D.new()
	head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.albedo_color = Color(1.0, 0.96, 0.86)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.93, 0.78)
	head.emission_energy_multiplier = 3.5
	for i in range(0, count, 26):
		for s in [-1.0, 1.0]:
			var r: Vector3 = _right_at(i * seg) * s
			var base: Vector3 = pts[i] + r * (half_w + WALL_T + 4.0)
			var mast := _box(self, Vector3(0.5, 22.0, 0.5), Vector3.ZERO, pole)
			mast.global_position = base + Vector3(0, 11.0, 0)
			var lamp := _box(self, Vector3(3.2, 0.5, 1.2), Vector3.ZERO, head)
			lamp.global_position = base + Vector3(0, 22.0, 0)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.92, 0.78)
			light.light_energy = 6.0
			light.omni_range = 55.0
			light.shadow_enabled = false
			light.position = base + Vector3(0, 20.0, 0)
			add_child(light)

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
		# moored beyond the quay, spread across the map width
		y.position = Vector3(_map_center.x + _rng.randf_range(-520, 120), -1.0,
			_z_limit + _rng.randf_range(35, 230))
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
			var c := pts[i] + r * (half_w + WALL_T + gap + d * 0.5)
			c.y = 0
			if c.z + maxf(w, d) * 0.5 > _z_limit:
				continue
			var cp := curve.get_closest_point(c - global_position)
			var clear := Vector2(cp.x - c.x, cp.z - c.z).length()
			if clear < maxf(w, d) * 0.72 + half_w + 2.0:
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
			pts[i] + r * (half_w + WALL_T + 1.0))

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
	_speed = v
	_time_at.resize(count + 1)
	_time_at[0] = 0.0
	for i in count:
		_time_at[i + 1] = _time_at[i] + seg / maxf(v[i], 5.0)
	ideal_time = _time_at[count]

## Ideal (braking-aware) speed in m/s at this offset; used by the AI.
func speed_at(off: float) -> float:
	return _speed[int(fposmod(off, length) / seg) % count]

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
