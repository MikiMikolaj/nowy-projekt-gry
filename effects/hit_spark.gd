# HitSpark: one-shot particle burst at a hit point, aimed along the attack. Frees itself when finished.
class_name HitSpark
extends CPUParticles2D

const SCENE_PATH: String = "res://effects/hit_spark.tscn"


# Spawns a spark in `parent` at a world position. Anything that lands a hit can call this.
static func spawn(parent: Node2D, global_pos: Vector2, attack_direction: Vector2) -> void:
	var spark: HitSpark = (load(SCENE_PATH) as PackedScene).instantiate() as HitSpark
	# Positioned before entering the tree, so physics interpolation never draws it at the parent's origin.
	spark.position = parent.to_local(global_pos)
	spark.direction = attack_direction
	parent.add_child(spark)
	spark.reset_physics_interpolation()
	spark.restart()


func _ready() -> void:
	finished.connect(queue_free)
