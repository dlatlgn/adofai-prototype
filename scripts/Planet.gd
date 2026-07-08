class_name Planet
extends Node2D

var is_fire: bool = true
var radius: float = 30.0
var pulse: float = 0.0

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 3.5)
		queue_redraw()

func trigger_pulse() -> void:
	pulse = 1.0
	queue_redraw()

func _draw() -> void:
	var base: Color = Color(1.00, 0.35, 0.10) if is_fire else Color(0.30, 0.72, 1.00)
	var r: float = radius + pulse * 14.0

	# 바깥 확산 글로우
	draw_circle(Vector2.ZERO, r + 18.0, Color(base.r, base.g, base.b, 0.10))
	draw_circle(Vector2.ZERO, r + 10.0, Color(base.r, base.g, base.b, 0.22))
	# 본체
	draw_circle(Vector2.ZERO, r, base)
	# 흰 테두리
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 1, 1, 0.9), 2.5, true)
	# 펄스 시 순간 확산 링
	if pulse > 0.01:
		draw_arc(Vector2.ZERO, r + pulse * 22.0, 0.0, TAU, 64,
			Color(1, 1, 1, pulse * 0.8), 3.0 * pulse, true)
