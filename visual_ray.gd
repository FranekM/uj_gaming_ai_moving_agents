extends Node2D

var end_point : Vector2 = Vector2.ZERO

func _draw() -> void:
	draw_line(Vector2.ZERO, end_point, Color.ORANGE)

func set_end_point(_end_point : Vector2) -> void:
	end_point = to_local(_end_point)
	queue_redraw()
