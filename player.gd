class_name Player extends CharacterBody2D

@onready var visual_ray : Node2D = $visual_ray

const RAY_VISIBLE_TIME := 0.1  # seconds
const RAY_LENGTH := 2000.0
const RAY_MASK := (1 << 2) + (1 << 1)

const MOVE_FORCE := 2000.0
const MAX_SPEED := 125.0
const DAMPING := 0.8

const ROTATION_IMPULSE := 100.0
const ANGULAR_DAMPING := 0.8
const MAX_ANGULAR_SPEED := 100.0

var angular_velocity := 0.0

var radius = Enemy.ENEMY_RADIUS

var main_scene : MainScene = null
var health : int = 100

func _physics_process(delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.001:
		var target_angle := to_mouse.angle() - PI / 2  # UP is forward
		var angle_diff := wrapf(target_angle - rotation, -PI, PI)
		angular_velocity += angle_diff * ROTATION_IMPULSE * delta

	angular_velocity = clamp(
		angular_velocity,
		-MAX_ANGULAR_SPEED,
		MAX_ANGULAR_SPEED
	)

	rotation += angular_velocity * delta
	angular_velocity *= ANGULAR_DAMPING

	var forward := -Vector2.UP.rotated(rotation)
	var right := -Vector2.RIGHT.rotated(rotation)

	var thrust := \
		forward * (
			Input.get_action_strength("move_forward")
			- Input.get_action_strength("move_backward")
		) + \
		right * (
			Input.get_action_strength("move_right")
			- Input.get_action_strength("move_left")
		)

	if thrust != Vector2.ZERO:
		velocity += thrust.normalized() * MOVE_FORCE * delta

	velocity = velocity.limit_length(MAX_SPEED)
	velocity *= DAMPING

	if Input.is_action_just_pressed("fire_ray"):
		fire_ray()

	position += velocity * delta
	enforce_non_penetration_constraint()
	enforce_wall_non_penetration_constraint()

func _draw() -> void:
	var points = PackedVector2Array([Vector2(-8.667, -5.0), Vector2(8.667, -5.0), Vector2(0.0, 10.0)])
	var colors = PackedColorArray([Color.GREEN, Color.GREEN, Color.GREEN])
	draw_polygon(points, colors)


func enforce_non_penetration_constraint() -> void:
	for e in main_scene.obstacles:
		var to_e = global_position - e.global_position
		var dist = to_e.length()
		var overlap = e.radius + radius - dist
		if overlap >= 0:
			position += to_e / dist * overlap

func enforce_wall_non_penetration_constraint() -> void:
	if global_position.x < radius:
		global_position.x = radius
	if global_position.x > main_scene.VIEWPORT_DIM.x - radius:
		global_position.x = main_scene.VIEWPORT_DIM.x - radius
	if global_position.y < radius:
		global_position.y = radius
	if global_position.y > main_scene.VIEWPORT_DIM.y - radius:
		global_position.y = main_scene.VIEWPORT_DIM.y - radius


func cast_ray() -> Dictionary:
	var space = get_world_2d().direct_space_state
	var from = global_position
	var forward = Vector2.UP.rotated(rotation)
	var to = from - forward * RAY_LENGTH
	
	var params = PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = RAY_MASK
	
	return space.intersect_ray(params)

func fire_ray() -> void:
	var result : Dictionary = cast_ray()
	var end_point : Vector2 = global_position - Vector2.UP.rotated(rotation) * RAY_LENGTH
	
	if result:
		end_point = result.position
		var collider : Object = result.collider
		if collider is Enemy:
			collider.queue_free()
			main_scene.enemies.erase(collider)
			if main_scene.enemies.is_empty():
				get_tree().paused = true
				main_scene.game_over.visible = true
				main_scene.game_over_label.text = "YOU WON"
	
	visual_ray.set_end_point(end_point)
	visual_ray.visible = true
	await get_tree().create_timer(RAY_VISIBLE_TIME).timeout
	visual_ray.visible = false
