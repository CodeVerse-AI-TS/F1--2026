extends Node3D
## Translucent ghost car that drives the gold-target lap along the racing line.

const CarModelScript = preload("res://scripts/car_model.gd")

var model: Node3D

func _ready() -> void:
	model = CarModelScript.new()
	model.ghost = true
	add_child(model)
	visible = false

func place(track: Node3D, off: float, delta: float) -> void:
	global_transform = track.get_xform(off)
	model.update_visual(delta, 60.0, 0.0, 0.0)
