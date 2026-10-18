extends MeshInstance3D
## Full-screen lens flare pass. Instance lens_flare.tscn anywhere in a 3D scene: it follows the
## sun (the brightest visible DirectionalLight3D, or `sun` if set) and draws an additive glare,
## starburst, streak and ghost chain while the sun is on screen. Geometry covering the sun (read
## from the depth buffer) dims it smoothly. Set `strength` to 0 to hide it (zero cost).

## Sun to follow. Empty = the brightest visible DirectionalLight3D in the scene (re-checked every second).
@export var sun: DirectionalLight3D
## Multiply the material's flare_color with the sun's light_color.
@export var use_sun_color := false
## Master fade, 0..1. 0 hides the node.
@export_range(0.0, 1.0, 0.01) var strength := 1.0:
	set(v):
		strength = v
		visible = v > 0.0
		if material_override:
			(material_override as ShaderMaterial).set_shader_parameter("strength", v)

var _found: DirectionalLight3D
var _scan_t := 0.0
var _base_color := Color(1, 1, 1)


func _ready() -> void:
	var m := material_override as ShaderMaterial
	if m:
		var c: Variant = m.get_shader_parameter("flare_color")
		if c is Color:
			_base_color = c
		m.set_shader_parameter("strength", strength)
	visible = strength > 0.0


## Change a shader parameter: intensity, flare_color, glare, starburst, streak, streak_color,
## ghosts, halo, size, occlusion_radius. Example: $LensFlare.set_param("ghosts", 1.5)
func set_param(param: String, value: Variant) -> void:
	var m := material_override as ShaderMaterial
	if m:
		m.set_shader_parameter(param, value)
	if param == "flare_color" and value is Color:
		_base_color = value


func _process(delta: float) -> void:
	var l := sun if is_instance_valid(sun) else _auto_sun(delta)
	var m := material_override as ShaderMaterial
	if m == null:
		return
	if l == null:
		# No sun in the scene: draw nothing instead of rays from a default direction.
		m.set_shader_parameter("strength", 0.0)
		return
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("sun_direction", l.global_transform.basis.z.normalized())
	if use_sun_color:
		m.set_shader_parameter("flare_color", _base_color * l.light_color)


func _auto_sun(delta: float) -> DirectionalLight3D:
	_scan_t -= delta
	if is_instance_valid(_found) and _found.is_visible_in_tree() and _scan_t > 0.0:
		return _found
	_scan_t = 1.0
	_found = null
	var best := -1.0
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		var d := n as DirectionalLight3D
		if d.is_visible_in_tree() and d.sky_mode != DirectionalLight3D.SKY_MODE_SKY_ONLY and d.light_energy > best:
			best = d.light_energy
			_found = d
	return _found
