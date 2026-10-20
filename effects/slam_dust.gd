# SlamDust: a two-way dust burst along the floor where a slam lands. Frees itself when finished.
class_name SlamDust
extends Node2D

const SCENE_PATH: String = "res://effects/slam_dust.tscn"

@onready var _left: CPUParticles2D = $DustLeft
@onready var _right: CPUParticles2D = $DustRight


# Spawns a burst in `parent` at a world position (the slammer's feet).
static func spawn(parent: Node2D, global_pos: Vector2) -> void:
	var dust: SlamDust = (load(SCENE_PATH) as PackedScene).instantiate() as SlamDust
	# Positioned before entering the tree, so physics interpolation never draws it at the parent's origin.
	dust.position = parent.to_local(global_pos)
	parent.add_child(dust)
	dust.reset_physics_interpolation()


func _ready() -> void:
	_right.finished.connect(queue_free)
	_left.restart()
	_right.restart()
