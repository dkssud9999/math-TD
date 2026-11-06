extends Node2D
## Carries an operator to its target function.

var target = null
var op: String = ""
var params: Dictionary = {}
var color: Color = Color.WHITE
var speed: float = 520.0
var t: float = 0.0


func _process(delta: float) -> void:
	t += delta
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return
	var to: Vector2 = target.global_position - global_position
	var step := speed * delta
	if to.length() <= step + 8.0:
		target.apply_op(op, params)
		queue_free()
		return
	global_position += to.normalized() * step
	queue_redraw()


func _draw() -> void:
	match op:
		"diff":
			draw_line(Vector2(-5, 0).rotated(t * 18.0), Vector2(5, 0).rotated(t * 18.0), color, 2.0)
			draw_circle(Vector2.ZERO, 2.5, color)
		"int":
			draw_arc(Vector2.ZERO, 5.0, t * 10.0, t * 10.0 + PI * 1.3, 10, color, 2.0)
		"mod":
			draw_rect(Rect2(-3, -3, 6, 6), color)
		_:
			draw_circle(Vector2.ZERO, 3.5, color)
