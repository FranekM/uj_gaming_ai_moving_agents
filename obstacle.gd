class_name Obstacle extends StaticBody2D

const VIEWPORT_DIM = Vector2(1800, 900)
const OBSTACLE_RADIUS_MIN = VIEWPORT_DIM.y / 25
const OBSTACLE_RADIUS_MAX = VIEWPORT_DIM.y / 10

@onready var collision_shape:CollisionShape2D = $collision_shape

var radius : float = 0.0

func _ready() -> void:
	radius = randf_range(OBSTACLE_RADIUS_MIN, OBSTACLE_RADIUS_MAX)
	collision_shape.shape = collision_shape.shape.duplicate()
	collision_shape.shape.radius = radius
	reposition()
	#queue_redraw()

func reposition() -> void:
	position = Vector2(
		randf_range(radius * 2.0, VIEWPORT_DIM.x - radius * 2.0),
		randf_range(radius * 2.0, VIEWPORT_DIM.y - radius * 2.0)
	)

func _draw() -> void:
	if collision_shape.shape is CircleShape2D:
		draw_circle(Vector2.ZERO, collision_shape.shape.radius, Color.BLACK, true, -1.0, true)
