class_name Planet
extends Node2D

var is_fire: bool = true
var radius: float = 22.0
var pulse: float = 0.0  # 0~1, 히트 시 확 커졌다 줄어드는 효과

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 4.0)
		queue_redraw()

func trigger_pulse() -> void:
	pulse = 1.0
	queue_redraw()

func _draw() -> void:
	var base: Color = Color(1.0, 0.3, 0.1) if is_fire else Color(0.3, 0.7, 1.0)
	var r: float   = radius + pulse * 10.0
	# glow
	draw_circle(Vector2.ZERO, r + 8.0, Color(base.r, base.g, base.b, 0.20))
	# body
	draw_circle(Vector2.ZERO, r, base)
	# rim
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 2.0)
	# highlight
	draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.55))
