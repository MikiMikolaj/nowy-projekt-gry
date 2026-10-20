# DeathBurst: a large one-shot particle burst where an enemy dies, in the enemy's colour. Frees itself.
class_name DeathBurst
extends CPUParticles2D

const SCENE_PATH: String = "res://effects/death_burst.tscn"


static func spawn(parent: Node2D, global_pos: Vector2, burst_color: Color) -> void:
	var burst: DeathBurst = (load(SCENE_PATH) as PackedScene).instantiate() as DeathBurst
	# Positioned before entering the tree, so physics interpolation never draws it at the parent's origin.
	burst.position = parent.to_local(global_pos)
	burst.color = burst_color
	parent.add_child(burst)
	burst.reset_physics_interpolation()
	burst.restart()


func _ready() -> void:
	finished.connect(queue_free)
