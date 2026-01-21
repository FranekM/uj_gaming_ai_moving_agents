class_name Enemy extends CharacterBody2D

const VIEWPORT_DIM = Vector2(1800, 900)
const ENEMY_RADIUS : float = 10.0
const MAX_SPEED : float = 75.0

const WALL_MASK : int = 1 << 3
const OBSTACLE_MASK : int = 1 << 2

@onready var collision : CollisionShape2D = $collision
@onready var detector : Area2D = $detector
@onready var flock_detector : Area2D = $flock_detector
@onready var detector_collision : CollisionShape2D = $detector/collision
@onready var damage_timer : Timer = $damage_timer

var main_scene : MainScene = null
var radius = ENEMY_RADIUS

# local space vectors
var heading : Vector2 = Vector2(0.0, 1.0)
var side : Vector2 = Vector2(1.0, 0.0)
var speed : float = 0.0

# wander parameters
var wander_radius : float = MAX_SPEED / 3.0
var wander_distnc : float = MAX_SPEED / 2.0
var wander_jitter : float = MAX_SPEED / 10.0
var wander_target : Vector2 = Vector2.ZERO

# avoidance parameters
var feelers : Array[Vector2] = []
var detector_length : float = 0

# hiding parameters
var bravery_level : float = 0.0
var bravery_jitter : float = 0.05

# attack mode
var critical_mass = 10
var flock_count = 0
var is_attacking = false
var can_damage = false

# area detection
var flock : Array[Enemy] = []
var is_player_in_area : bool = false
var obstacles_in_area : Array[Obstacle] = []
var obstacles_in_front : Array[Obstacle] = []
var enemies_in_fornt : Array[Enemy] = []

# steering forces 
var force_wander : Vector2 = Vector2.ZERO
var force_avoid_obstacle : Vector2 = Vector2.ZERO
var force_avoid_enemy : Vector2 = Vector2.ZERO
var force_avoid_wall : Vector2 = Vector2.ZERO
var force_evade : Vector2 = Vector2.ZERO
var force_hide : Vector2 = Vector2.ZERO
var force_pursuit : Vector2 = Vector2.ZERO 
var force_separation : Vector2 = Vector2.ZERO
var force_cohesion : Vector2 = Vector2.ZERO
var force_alignment : Vector2 = Vector2.ZERO

# steering points
var slalom_mid_point : Vector2 = Vector2.ZERO
var mass_center = Vector2.ZERO

func _ready() -> void:
	detector_collision.shape = detector_collision.shape.duplicate()
	collision.shape = collision.shape.duplicate()
	(collision.shape as CircleShape2D).radius = ENEMY_RADIUS
	reposition()
	reshape_detector()
	
func _exit_tree() -> void:
	main_scene.enemies.erase(self)
	for e in main_scene.enemies:
		e.flock.erase(self)
		e.enemies_in_fornt.erase(self)
	
func reposition() -> void:
	position = Vector2(
		randf_range(0.0, VIEWPORT_DIM.x),
		randf_range(0.0, VIEWPORT_DIM.y)
	)

func reshape_detector() -> void:
	detector_length = max(speed * 2.0, ENEMY_RADIUS * 4.0)
	var size = Vector2(detector_length * 0.5, ENEMY_RADIUS * 3.0)
	(detector_collision.shape as RectangleShape2D).size = size
	detector_collision.position = Vector2(size.x / 2.0, 0.0)


# ===================
# INDYVIDUAL BEHABIOR
# ===================

func seek(to : Vector2) -> Vector2:
	var desired_velocity = (to - global_position).normalized() * MAX_SPEED
	return desired_velocity - velocity

func flee(from : Vector2) -> Vector2:
	var desired_velocity = (global_position - from).normalized() * MAX_SPEED
	return desired_velocity - velocity

func evade(pursuer : CharacterBody2D) -> Vector2:
	var to_pursuer = pursuer.global_position - global_position
	var look_ahead_time = to_pursuer.length() / (MAX_SPEED + MAX_SPEED)
	return flee(pursuer.global_position + pursuer.velocity * look_ahead_time)

func arrive(to : Vector2) -> Vector2:
	var to_target = to - global_position
	var dist = to_target.length()
	if dist == 0:
		return Vector2.ZERO
	var arrive_speed = min(dist / 0.3, MAX_SPEED)
	var desired_velocity = to_target * arrive_speed / dist
	return desired_velocity - velocity

func arrive_slalom(to : Vector2) -> Vector2:
	if Engine.get_physics_frames() % 1 == 0:
		var result = cast_ray(to, OBSTACLE_MASK)
		slalom_mid_point = Vector2.ZERO
		if not result.is_empty() and result.collider is Obstacle:
			var to_target = (to - global_position).normalized()
			var angle = 2.0 * PI / 3.0
			var offset_dir = to_target.rotated(angle)
			if offset_dir.dot(velocity) < 0:
				offset_dir = to_target.rotated(-angle)
			var offset_len = result.collider.radius + main_scene.hide_distance_from_obsbtacle
			slalom_mid_point = result.collider.global_position + (offset_dir * offset_len)
	if not slalom_mid_point == Vector2.ZERO:
		return arrive(slalom_mid_point)
	return arrive(to)

func wander() -> Vector2:
	wander_target += Vector2(
		randf_range(-1.0, 1.0) * wander_jitter,
		randf_range(-1.0, 1.0) * wander_jitter
	)
	wander_target = wander_target.normalized()
	wander_target *= wander_radius
	var target_local : Vector2 = wander_target + Vector2(wander_distnc, 0.0)
	var target_world : Vector2 = to_global(target_local)
	return target_world - position

func obstacle_avoidance(bodies : Array) -> Vector2:
	var steering_force : Vector2 = Vector2.ZERO
	var closest_local : Vector2 = Vector2.ZERO
	var closest_radius : float = 0.0
	var closest_dist : float = INF
	
	for body in bodies:
		if body == self: continue
		if body is Enemy and is_attacking and body.is_attacking: continue
		var local = to_local_vec(body.global_position - global_position)
		if local.x > 0 and abs(local.y) < closest_dist:
			closest_dist = abs(local.y)
			closest_local = local
			closest_radius = body.radius + detector_length
	
	if closest_local == Vector2.ZERO:
		return Vector2.ZERO
	
	var multiplier = 1.0 + (detector_length - closest_local.x) / detector_length
	var lateral_sign = - sign(closest_local.y)
	var penetartion = closest_radius - abs(closest_local.y)
	steering_force.y = lateral_sign * penetartion * multiplier
	steering_force.x = (closest_radius - closest_local.x) * -0.2
	return to_world_vec(steering_force)

func wall_avoidance() -> Vector2:
	var closest_dist : float = INF
	var closest_pos = Vector2.ZERO
	var closest_normal = Vector2.ZERO
	var closest_feeler = Vector2.ZERO
	var feeler_len = speed + 10.0
	
	feelers.resize(3)
	feelers[0] = heading * feeler_len
	feelers[1] = side * feeler_len * 0.5
	feelers[2] = -side * feeler_len * 0.5
	
	for feeler in feelers:
		var end = global_position + feeler
		var hit_pos = Vector2.ZERO
		var normal = Vector2.ZERO
		var hit = false
		
		if end.x < 0:
			hit = true
			hit_pos = Vector2(0, end.y)
			normal = Vector2.RIGHT
		elif end.x > VIEWPORT_DIM.x:
			hit = true
			hit_pos = Vector2(VIEWPORT_DIM.x, end.y)
			normal = Vector2.LEFT
		elif end.y < 0:
			hit = true
			hit_pos = Vector2(end.x, 0)
			normal = Vector2.DOWN
		elif end.y > VIEWPORT_DIM.y:
			hit = true
			hit_pos = Vector2(end.x, VIEWPORT_DIM.y)
			normal = Vector2.UP

		if not hit:
			continue
		
		var dist = global_position.distance_to(hit_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_pos = hit_pos
			closest_normal = normal
			closest_feeler = feeler
	
	if closest_dist == INF:
		return Vector2.ZERO
	
	var overshoot = global_position + closest_feeler - closest_pos
	return closest_normal * overshoot.length()

func hide_from_player() -> Vector2:
	var hideout = get_closest_hideout(position, main_scene.hiding_positions)
	var obstacle = cast_ray(hideout, OBSTACLE_MASK)
	if obstacle.is_empty():
		return arrive(hideout)
	if obstacle.collider is Obstacle:
		var to_hideout = (hideout - global_position).normalized()
		var angle = 2.0 * PI / 3.0
		var offset_dir = to_hideout.rotated(angle)
		#if not force_evade.is_zero_approx():
			#if offset_dir.fot(force_evade) < 0:
				#offset_dir = to_hideout.rotated(-angle)
		if offset_dir.dot(velocity) < 0:
			offset_dir = to_hideout.rotated(-angle)
		var offset_len = obstacle.collider.radius + main_scene.hide_distance_from_obsbtacle
		var point = obstacle.collider.global_position + (offset_dir * offset_len)
		return arrive(point)
	return Vector2.ZERO


# =================
# GROUP BEHAVIOURS
# =================

func separation() -> Vector2:
	var steering_force = Vector2.ZERO
	for e in flock:
		var to_agent = global_position - e.global_position
		steering_force += to_agent.normalized() / max(to_agent.length(), 1.0)
	return steering_force

func cohesion() -> Vector2:
	var steering_force = Vector2.ZERO
	mass_center = Vector2.ZERO
	var count = 0
	for e in flock:
		if e.is_attacking != is_attacking:
			continue
		mass_center += e.global_position
		count += 1
	if count > 0:
		mass_center /= count
		var to_mass_center = mass_center - global_position
		steering_force = seek(mass_center).normalized()
		steering_force *= to_mass_center.length()
	return steering_force
	
func alignment() -> Vector2:
	var steering_force = Vector2.ZERO
	var count = 0
	for e in flock:
		if e.is_attacking != is_attacking:
			continue
		steering_force += e.heading
		count += 1
	if count > 0:
		steering_force /= count
		steering_force -= heading
	return steering_force


#func get_best_hideout(from : Vector2, positions : Array[Vector2]) -> Vector2:
	#var best = Vector2.ZERO
	#var best_dist = INF
	#var to_pursuer = main_scene.player.global_position - global_position
	#for pos in positions:
		#var dir = (pos - global_position).normalized()
		#if dir.dot(to_pursuer) > 0 and cast_hide_ray().is_empty():
			#continue
		#var d = from.distance_squared_to(pos)
		#if d < best_dist:
			#best_dist = d
			#best = pos
	#return best
	
	
# ==================
# COLLISION HANDLING
# ==================

func handle_agent_colisions() -> void:
	for e in flock:
		enforce_non_penetration_constraint(e)
	if is_player_in_area:
		var overlap = enforce_non_penetration_constraint(main_scene.player)
		if overlap > 0 and can_damage:
			damage()
	for o in obstacles_in_area:
		enforce_non_penetration_constraint(o)
			
func enforce_non_penetration_constraint(e : PhysicsBody2D) -> float:
	var to_e = global_position - e.global_position
	var dist = to_e.length()
	var overlap = e.radius + ENEMY_RADIUS - dist
	if overlap >= 0:
		position += to_e / dist * overlap
	return overlap
	
func handle_wall_collisions() -> void:
	if global_position.x < radius:
		global_position.x = radius
	if global_position.x > main_scene.VIEWPORT_DIM.x - radius:
		global_position.x = main_scene.VIEWPORT_DIM.x - radius
	if global_position.y < radius:
		global_position.y = radius
	if global_position.y > main_scene.VIEWPORT_DIM.y - radius:
		global_position.y = main_scene.VIEWPORT_DIM.y - radius


# ==================
# AXULIARY FUNCTIONS
# ==================

func to_local_vec(vec : Vector2) -> Vector2:
	return Vector2(vec.dot(heading), vec.dot(side))
	
func to_world_vec(vec : Vector2) -> Vector2:
	return heading * vec.x + side * vec.y

func get_closest_hideout(from : Vector2, positions : Array[Vector2]) -> Vector2:
	var closest = Vector2.ZERO
	var closest_dist = INF
	for pos in positions:
		var d = from.distance_squared_to(pos)
		if d < closest_dist:
			closest_dist = d
			closest = pos
	return closest

func cast_ray(to : Vector2, mask : int) -> Dictionary:
	var space = get_world_2d().direct_space_state
	var from = global_position
	var params = PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collision_mask = mask
	return space.intersect_ray(params)


# ======================
# STATE UPDATE FUNCTIONS
# ======================

func update_bravery(delta : float) -> void:
	if bravery_level < 0.1 and randf() < 0.0005:
		bravery_level = 1.0
	bravery_level = max(bravery_level - 0.08 * delta, 0.0)
	#bravery_level = 1.0

func check_for_critical_mass() -> void:
	critical_mass = floor(main_scene.enemies.size() / 10.0)
	flock_count = 0
	for e in flock:
		if not e.is_attacking:
			flock_count += 1
	if flock_count >= critical_mass:
		activate_attac()
		
func activate_attac() -> void:
	if not is_attacking:
		is_attacking = true
		can_damage = true
		for e in flock:
			e.activate_attac()

func damage() -> void:
	main_scene.player.health -= 1
	main_scene.health_bar.value = main_scene.player.health
	# game over
	if main_scene.player.health <= 0:
		main_scene.player.queue_free()
		main_scene.game_over.visible = true
		get_tree().paused = true
	can_damage = false
	damage_timer.start()

func _on_damage_timer_timeout() -> void:
	can_damage = true

# ===========================
# PHSYICS PROCESS AND DRAWING
#============================

func _physics_process(delta: float) -> void:
	speed = velocity.length()
	heading = velocity.normalized()
	side = Vector2(-heading.y, heading.x)
	
	var force = Vector2.ZERO
	force_pursuit = Vector2.ZERO
	force_separation = Vector2.ZERO
	force_cohesion = Vector2.ZERO
	force_alignment = Vector2.ZERO
	force_hide = Vector2.ZERO
	force_evade = Vector2.ZERO
	force_wander = Vector2.ZERO
	force_avoid_obstacle = Vector2.ZERO
	force_avoid_enemy = Vector2.ZERO
	force_avoid_wall = Vector2.ZERO
	
	if Engine.get_physics_frames() % 4 == 0:
		if abs(detector_length - speed) > speed * 0.5:
			reshape_detector()
		var bodies_in_front = detector.get_overlapping_bodies()
		bodies_in_front.erase(self)
		obstacles_in_front.clear()
		enemies_in_fornt.clear()
		for body in bodies_in_front:
			if body is Obstacle: obstacles_in_front.append(body)
			if body is Enemy: enemies_in_fornt.append(body)
	
	if Engine.get_physics_frames() % 4 == 1:
		var bodies_in_area = flock_detector.get_overlapping_bodies()
		bodies_in_area.erase(self)
		obstacles_in_area.clear()
		flock.clear()
		is_player_in_area = false
		for body in bodies_in_area:
			if body is Obstacle: obstacles_in_area.append(body)
			if body is Enemy: flock.append(body)
			if body is Player: is_player_in_area = true
	
	#var hide_strength = 1.0
	#
	#if Engine.get_physics_frames() % 4 == 2:
		#var result = cast_ray(main_scene.player.global_position, OBSTACLE_MASK)
		#hide_strength = 1.0
		#if result.is_empty():
			#hide_strength = 1.0
	
	force_avoid_obstacle = obstacle_avoidance(obstacles_in_front)
	force_avoid_enemy = obstacle_avoidance(enemies_in_fornt)
	force_avoid_wall = wall_avoidance()
	force_separation = separation()
	
	if is_attacking:
		force_pursuit = arrive_slalom(main_scene.player.global_position)
		force_cohesion = cohesion()
		force_alignment = alignment()
		force_avoid_obstacle *= 2.5
		force_avoid_enemy *= 2.0
	else:
		update_bravery(delta)
		check_for_critical_mass()
		force_hide = hide_from_player()
		force_wander = wander()
		if is_player_in_area:
			force_evade = evade(main_scene.player)
	
	if speed > MAX_SPEED * 0.5:
		force += force_cohesion * 0.5
	force += force_pursuit * 1.0
	force += force_alignment * 100.0
	force += force_separation * 500.0
	#force += force_evade * 50.0
	force += force_hide * (1.0 - bravery_level) # * hide_strength
	force += force_wander * clamp(bravery_level, 0.333, 1.0)
	force += force_avoid_obstacle * 2
	force += force_avoid_enemy * 2
	force += force_avoid_wall * 25.0
	
	velocity += force * delta
	velocity = velocity.limit_length(MAX_SPEED)
	rotation = velocity.normalized().angle()
	
	if Engine.get_physics_frames() % 5 == 0:
		queue_redraw()
	position += velocity * delta
	handle_agent_colisions()
	handle_wall_collisions()
	
func _draw() -> void:
	# debug movment
	draw_set_transform_matrix(global_transform.affine_inverse())
	#draw_line(position, position + velocity, Color.RED)
	#draw_line(position, position + force_wander, Color.AQUA)
	#draw_circle(position + velocity.normalized() * wander_distnc, wander_radius, Color.SLATE_BLUE, false)
	#draw_circle(position + force_wander, 5.0, Color.RED)
	
	#for n in neighbors:
		#var color_distance = Color.WHITE
		#draw_line(global_position, n.global_position, color_distance)
		#draw_circle(global_position, neighbor_radius, Color.WHITE, false)
	
	#for hp in main_scene.hiding_positions:
		#draw_circle(hp, 5.0, Color.NAVY_BLUE)
	#draw_circle(temp_point, 5.0, Color.CRIMSON)
	#draw_circle(selected_point, 5.0, Color.DARK_RED)
	#draw_circle(slalom_mid_point, 5.0, Color.DARK_BLUE)
	
	#if is_attacking:
	
		#draw_line(global_position, global_position + force_wander, Color.RED)
	#draw_line(global_position, global_position + force_avoid_obstacle * 5, Color.GREEN)
		#draw_line(global_position, global_position + force_avoid_enemy, Color.YELLOW)
		#draw_line(global_position, global_position + force_avoid_wall, Color.GREEN)
		#draw_line(global_position, global_position + force_hide, Color.BLUE)
		#draw_line(global_position, global_position + velocity, Color.BLACK)
		
	#draw_line(global_position, global_position + force_pursuit, Color.FOREST_GREEN)
	#draw_line(global_position, global_position + force_separation * 500.0, Color.WHITE)
		#draw_line(global_position, global_position + force_cohesion, Color.RED)
		#draw_line(global_position, global_position + force_alignment, Color.LIGHT_BLUE)
		
	#for feeler in feelers:
		#draw_line(global_position, global_position + feeler, Color.BLUE_VIOLET)
	
	#draw_circle(mass_center, 5.0, Color.LIGHT_GREEN)
	
	# debug obstacle avoidance
	#draw_line(position, position + force_avoid_obstacle, Color.ALICE_BLUE)
	#draw_line(position, position + force_avoid_enemy, Color.ALICE_BLUE)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	#draw_rect(detection_box, Color.WHITE, false)

	# enemy visual
	if is_attacking:
		var color = Color.DARK_RED
		draw_circle(Vector2.ZERO, ENEMY_RADIUS, color)
	else:
		var color_bravery = Color.BLUE.lerp(Color.WHITE, bravery_level)
		draw_circle(Vector2.ZERO, ENEMY_RADIUS, color_bravery)
		var color_critical = Color.YELLOW.lerp(Color.DARK_RED, flock_count as float / critical_mass)
		draw_circle(Vector2.ZERO, ENEMY_RADIUS / 2.5, color_critical)
