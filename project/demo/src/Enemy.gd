extends CharacterBody3D

@export var MOVE_SPEED: float = 20.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@export var target: Node3D

var t := 1.0

func _process(delta: float) -> void:
	t += delta
	if t > 1.0 && target:
		nav_agent.set_target_position(target.global_position)

func is_on_nav_mesh() -> bool:
	var closest_point := NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), global_position)
	return global_position.distance_squared_to(closest_point) < nav_agent.path_max_distance ** 2

func _physics_process(_delta) -> void:
	if nav_agent.is_navigation_finished() || !nav_agent.is_target_reachable() || !is_on_nav_mesh():
		velocity = Vector3.ZERO
	else:
		var next_path_position: Vector3 = nav_agent.get_next_path_position()
		var current_agent_position: Vector3 = global_position
		velocity = (next_path_position - current_agent_position).normalized() * MOVE_SPEED
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(velocity)
	else:
		_on_velocity_computed(velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
