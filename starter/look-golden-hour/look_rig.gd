extends Node3D
## Drop-in look: this node owns the scene's WorldEnvironment and sun.
## Instance the look scene once, as a child of the main 3D scene root.
##
## take_over (default on): at runtime every other WorldEnvironment in the tree is
## given this look's Environment, and every DirectionalLight3D outside this rig
## is hidden, so the look wins even when the scene already had default lighting.
## Turn it off to keep your own sun or environment.

@export var take_over := true
## env.tres is tuned for the Compatibility renderer (browser and cloud editor).
## These Environment properties replace it when the game runs Forward+ or Mobile.
@export var forward_plus_overrides: Dictionary = {}

# Environments taken from other WorldEnvironments stay referenced until this rig leaves
# the tree (freeing a used Sky mid-run leaks its radiance map in the GLES3 renderer).
var _displaced: Array[Environment] = []

func _ready() -> void:
	var own := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if own and own.environment and not forward_plus_overrides.is_empty() \
			and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var env := own.environment.duplicate() as Environment
		for key in forward_plus_overrides:
			env.set(key, forward_plus_overrides[key])
		own.environment = env
	if take_over:
		_take_over.call_deferred()

func _take_over() -> void:
	var own := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if own == null or own.environment == null:
		return
	for we: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if we != own and not is_ancestor_of(we) and we.environment != own.environment:
			if we.environment:
				_displaced.append(we.environment)
			we.environment = own.environment
	for light: DirectionalLight3D in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if not is_ancestor_of(light):
			light.visible = false
	var cam := get_viewport().get_camera_3d()
	if cam and cam.environment:
		cam.environment = null

## The Environment this look uses (for scripts that tweak it at runtime).
func get_environment() -> Environment:
	var own := get_node_or_null("WorldEnvironment") as WorldEnvironment
	return own.environment if own else null
