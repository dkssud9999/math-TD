extends Node2D
## Short-lived visual effects: floating text, Fourier rings, Limit zaps, bursts.

var kind: String = "text"
var life: float = 0.8
var max_life: float = 0.8
var text: String = ""
var color: Color = Color.WHITE
var size: int = 14
var radius: float = 60.0
var pts: PackedVector2Array = PackedVector2Array()


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if kind == "text":
		position.y -= 28.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(life / max_life, 0.0, 1.0)
	match kind:
		"text":
			Data.draw_text_centered(self, text, Vector2.ZERO, size, Color(color, minf(1.0, k * 1.6)))
		"ring":
			var rr := lerpf(radius * 0.15, radius, 1.0 - k)
			var ring := PackedVector2Array()
			for i in 65:
				var a := i * TAU / 64.0
				ring.append(Vector2.RIGHT.rotated(a) * (rr + 4.0 * sin(a * 8.0 + k * 12.0)))
			draw_polyline(ring, Color(color, k * 0.9), 2.0, true)
		"zap":
			draw_polyline(pts, Color(color, k), 2.0, true)
		"burst":
			for i in 8:
				var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
				draw_circle(d * (1.0 - k) * 26.0, 2.5 * k + 0.5, Color(color, k))
