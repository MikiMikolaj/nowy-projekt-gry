# StateMachine: runs exactly one child State at a time and forwards engine callbacks to it.
class_name StateMachine
extends Node

signal transitioned(from_state: StringName, to_state: StringName)

@export var initial_state: State

var current_state: State
var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			var state: State = child as State
			state.state_machine = self
			_states[state.name] = state
	# Wait for the owner (e.g. the player) to finish _ready so enter() can safely use its nodes.
	if owner != null and not owner.is_node_ready():
		await owner.ready
	if initial_state == null:
		push_error("StateMachine '%s' has no initial_state set." % get_path())
		return
	current_state = initial_state
	current_state.enter()


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


# state_name is the State node's name in the scene tree, e.g. &"Idle".
func transition_to(state_name: StringName) -> void:
	var next_state: State = _states.get(state_name)
	if next_state == null:
		push_error("StateMachine '%s' has no state named '%s'." % [get_path(), state_name])
		return
	var previous_name: StringName = &""
	if current_state != null:
		previous_name = current_state.name
		current_state.exit()
	current_state = next_state
	current_state.enter()
	transitioned.emit(previous_name, current_state.name)
