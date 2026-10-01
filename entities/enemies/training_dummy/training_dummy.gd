# TrainingDummy: takes hits forever (no HealthComponent = infinite HP). Flashes, wobbles and shows the damage number.
extends StaticBody2D

@export_group("Flash")
@export var flash_time: float = 0.08

@export_group("Wobble")
@export var wobble_degrees: float = 14.0
@export var wobble_time: float = 0.4

@export_group("Damage Number")
@export var number_font_size: int = 40
## How far the number floats up, in px, and how long it lives.
@export var number_rise: float = 80.0
@export var number_time: float = 0.5
## Top-left corner of the number, relative to the dummy's feet (above the head, clear of the flash).
@export var number_offset: Vector2 = Vector2(-12.0, -170.0)

var _base_color: Color
var _flash_tween: Tween
var _wobble_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _body: ColorRect = $Visual/Body
@onready var _hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	_base_color = _body.color
	# The wobble is animated per rendered frame, so it must not also be physics-interpolated.
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hurtbox.hit_received.connect(_on_hit_received)


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	var attacker: Node2D = hitbox.attacker as Node2D
	var away: float = 1.0
	if attacker != null and attacker.global_position.x > global_position.x:
		away = -1.0
	_wobble(away)
	_show_number(hitbox.attack_data.damage)


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_body.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_interval(flash_time)
	_flash_tween.tween_callback(func() -> void: _body.color = _base_color)


# Tips away from the attacker, then springs back upright.
func _wobble(away: float) -> void:
	if _wobble_tween != null:
		_wobble_tween.kill()
	_visual.rotation = deg_to_rad(wobble_degrees) * away
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(_visual, ^"rotation", 0.0, wobble_time) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_number(amount: int) -> void:
	var label: Label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override(&"font_size", number_font_size)
	label.position = number_offset
	label.z_index = 10
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(label)
	var tween: Tween = label.create_tween().set_parallel()
	tween.tween_property(label, ^"position:y", number_offset.y - number_rise, number_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"modulate:a", 0.0, number_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
