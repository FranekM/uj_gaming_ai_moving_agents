class_name MainScene extends Node2D

const VIEWPORT_DIM = Vector2(1800, 900)

const ENEMY_COUNT_INIT: int = 100
const OBSTACLE_COUNT_INIT: int = 12

@onready var walls : StaticBody2D = $walls
@onready var player : Player = $player
@onready var health_bar : ProgressBar = $gui/margin/container/health_bar
@onready var game_over : CanvasLayer = $game_over

# hinding variables
var hide_distance_from_obsbtacle : float = Obstacle.OBSTACLE_RADIUS_MIN / 1.5
var hiding_positions : Array[Vector2] = []

var obstacle_node = preload("res://obstacle.tscn")
var obstacles : Array[Obstacle] = []

var enemy_node = preload("res://enemy.tscn")
var enemies : Array[Enemy] = []

func _ready() -> void:
	walls.get_node("wall_north").position = Vector2(VIEWPORT_DIM.x / 2, 0.0)
	walls.get_node("wall_east").position = Vector2(0.0, VIEWPORT_DIM.y / 2)
	walls.get_node("wall_south").position = Vector2(VIEWPORT_DIM.x / 2, VIEWPORT_DIM.y)
	walls.get_node("wall_west").position = Vector2(VIEWPORT_DIM.x, VIEWPORT_DIM.y / 2)
	health_bar.value = 100.0 * player.health
	
	for i in range(OBSTACLE_COUNT_INIT):
		var obstacle_instance : Obstacle = obstacle_node.instantiate()
		obstacles.append(obstacle_instance)
		add_child(obstacle_instance)
		new_placement(obstacle_instance)
		
	for i in range(ENEMY_COUNT_INIT):
		spawn_enemy()
	
	player.position = Vector2(VIEWPORT_DIM.x / 2, VIEWPORT_DIM.y / 2)
	player.main_scene = self

func spawn_enemy() -> Enemy:
	var enemy_instance : Enemy = enemy_node.instantiate()
	enemy_instance.main_scene = self
	enemies.append(enemy_instance)
	add_child(enemy_instance)
	new_placement(enemy_instance)
	#enemy_instance.attac_mode = true
	return enemy_instance

func new_placement(body: PhysicsBody2D) -> bool:
	for _attempt in range(100):
		var valid = true
		for o in obstacles:
			if o == body: continue
			var min_dist = body.radius + o.radius + max(body.radius, o.radius)
			if body.position.distance_squared_to(o.position) < min_dist * min_dist:
				valid = false
				body.reposition()
				break
		#queue_redraw()
		#await get_tree().create_timer(0.05).timeout
		if valid:
			return true
	body.queue_free()
	return false  # failed to place

func update_hiding_positions() -> void:
	hiding_positions.clear()
	for obstacle in obstacles:
		var dist = obstacle.radius + hide_distance_from_obsbtacle
		var to_obstacle = (obstacle.position - player.position).normalized()
		var hiding_position = to_obstacle * dist + obstacle.position
		hiding_positions.append(hiding_position)

func _physics_process(_delta: float) -> void:
	update_hiding_positions()
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		spawn_enemy().position = event.position
