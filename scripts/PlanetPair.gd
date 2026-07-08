class_name PlanetPair
extends Node2D

const ARM_LENGTH: float = 90.0
const TRAIL_LEN: int    = 14

var fire: Planet
var ice: Planet

var fire_is_pivot: bool = true

# 회전 상태
var pivot_pos: Vector2 = Vector2.ZERO
var start_angle: float = PI
var rotation_delta: float = PI
var beat_time: float = 0.5
var elapsed: float = 0.0
var running: bool = false

# 잔상 (오래된 것 = 배열 앞, 최신 = 배열 뒤)
var _fire_trail: Array[Vector2] = []
var _ice_trail: Array[Vector2] = []
var _time: float = 0.0

func _ready() -> void:
	fire = Planet.new()
	fire.is_fire = true
	add_child(fire)

	ice = Planet.new()
	ice.is_fire = false
	add_child(ice)

	_update_positions(start_angle)
	_reset_trails()

func start_rotation(new_pivot: Vector2, from_angle: float, to_angle: float, duration: float, direction: int = 1) -> void:
	pivot_pos   = new_pivot
	start_angle = from_angle
	# direction : 1 = CCW(양수 회전), -1 = CW(음수 회전)
	var delta: float = to_angle - from_angle
	if direction > 0:
		while delta <= 0.001:
			delta += TAU
	else:
		while delta >= -0.001:
			delta -= TAU
	rotation_delta = delta
	beat_time      = duration
	elapsed        = 0.0
	running        = true
	_update_positions(start_angle)
	_reset_trails()
	queue_redraw()

func swap_roles() -> void:
	fire_is_pivot = not fire_is_pivot

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	_time += delta
	elapsed += delta
	var t: float = clampf(elapsed / beat_time, 0.0, 1.0)
	var current_angle: float = start_angle + rotation_delta * t
	_update_positions(current_angle)

	# 잔상 업데이트
	_fire_trail.append(fire.position)
	_fire_trail.pop_front()
	_ice_trail.append(ice.position)
	_ice_trail.pop_front()

	queue_redraw()

func _update_positions(angle: float) -> void:
	var rotator_pos: Vector2 = pivot_pos + Vector2.RIGHT.rotated(angle) * ARM_LENGTH
	if fire_is_pivot:
		fire.position = pivot_pos
		ice.position  = rotator_pos
	else:
		ice.position  = pivot_pos
		fire.position = rotator_pos

func _reset_trails() -> void:
	_fire_trail.clear()
	_ice_trail.clear()
	for i in TRAIL_LEN:
		_fire_trail.append(fire.position)
		_ice_trail.append(ice.position)

func _draw() -> void:
	if not running:
		return

	# 궤도 원
	draw_arc(pivot_pos, ARM_LENGTH, 0.0, TAU, 80, Color(1, 1, 1, 0.18), 2.2, true)
	draw_arc(pivot_pos, ARM_LENGTH, 0.0, TAU, 80, Color(1, 1, 1, 0.06), 8.0, true)

	# 잔상 : 3층 불꽃 그라데이션 (외곽 짙은 → 중간 → 밝은 코어) + 플리커
	# 오래된 것부터 그려 최신 잔상이 앞에 오도록
	for i in TRAIL_LEN:
		var life: float = float(i) / float(TRAIL_LEN - 1)   # 0=oldest, 1=newest
		var flicker: float = 0.80 + sin(_time * 12.0 + float(i) * 1.7) * 0.20
		var life2: float = life * life                       # 급격한 페이드

		# --- Fire trail : 짙은 붉음 → 오렌지 → 노랑 코어 ---
		var f_pos: Vector2 = _fire_trail[i]
		var f_r: float = fire.radius * life * 0.95 * flicker
		draw_circle(f_pos, f_r * 1.55, Color(0.90, 0.13, 0.04, life2 * 0.45))    # 외곽 옅은 진홍
		draw_circle(f_pos, f_r * 1.00, Color(1.00, 0.42, 0.10, life * 0.65))     # 중간 오렌지
		draw_circle(f_pos, f_r * 0.55, Color(1.00, 0.88, 0.50, life * 0.78))     # 밝은 노랑
		draw_circle(f_pos, f_r * 0.25, Color(1.00, 0.98, 0.85, life * 0.85))     # 흰빛 코어

		# --- Ice trail : 짙은 파랑 → 시안 → 백청 코어 (푸른 불꽃) ---
		var i_pos: Vector2 = _ice_trail[i]
		var i_r: float = ice.radius * life * 0.95 * flicker
		draw_circle(i_pos, i_r * 1.55, Color(0.05, 0.20, 0.85, life2 * 0.45))    # 외곽 짙은 파랑
		draw_circle(i_pos, i_r * 1.00, Color(0.20, 0.65, 1.00, life * 0.65))     # 중간 시안
		draw_circle(i_pos, i_r * 0.55, Color(0.75, 0.92, 1.00, life * 0.78))     # 밝은 백청
		draw_circle(i_pos, i_r * 0.25, Color(0.95, 0.98, 1.00, life * 0.85))     # 흰빛 코어

func trigger_landing_pulse() -> void:
	if fire_is_pivot:
		ice.trigger_pulse()
	else:
		fire.trigger_pulse()

# 현재 회전자(=피벗이 아닌 쪽) 위치
func rotator_position() -> Vector2:
	return ice.position if fire_is_pivot else fire.position
