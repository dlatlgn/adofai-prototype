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

	# 잔상 : 공 이미지의 복사본이 좌우로 흔들리며 페이드아웃
	#   - 오래된 잔상일수록 지터 폭이 크고 크기가 줄어들며 알파도 낮아짐
	#   - 각 인덱스 위상 오프셋으로 개별적으로 흔들려 "타오르는" 불규칙성 연출
	for i in TRAIL_LEN:
		var life: float = float(i) / float(TRAIL_LEN - 1)   # 0=oldest, 1=newest
		if life < 0.05:
			continue
		var age: float = 1.0 - life
		var jitter_amp: float = age * 11.0 + 2.0
		var jitter_x: float = sin(_time * 18.0 + float(i) * 2.3) * jitter_amp
		var jitter: Vector2 = Vector2(jitter_x, 0.0)
		var fade: float = life * life

		_draw_ghost(_fire_trail[i] + jitter, fire.radius, life, fade, Color(1.00, 0.35, 0.10))
		_draw_ghost(_ice_trail[i] + jitter,  ice.radius,  life, fade, Color(0.30, 0.72, 1.00))

func _draw_ghost(pos: Vector2, base_r: float, life: float, fade: float, base: Color) -> void:
	# 실제 공의 축소·페이드 복사본 (외곽 글로우 + 본체 + 얇은 흰 테두리)
	var r: float = base_r * (0.55 + life * 0.45)
	draw_circle(pos, r + 10.0, Color(base.r, base.g, base.b, fade * 0.12))  # outer glow
	draw_circle(pos, r + 5.0,  Color(base.r, base.g, base.b, fade * 0.26))  # inner glow
	draw_circle(pos, r,        Color(base.r, base.g, base.b, fade * 0.75))  # body
	if life > 0.35:
		draw_arc(pos, r, 0.0, TAU, 40, Color(1, 1, 1, fade * 0.5), 1.4, true)

func trigger_landing_pulse() -> void:
	if fire_is_pivot:
		ice.trigger_pulse()
	else:
		fire.trigger_pulse()

# 현재 회전자(=피벗이 아닌 쪽) 위치
func rotator_position() -> Vector2:
	return ice.position if fire_is_pivot else fire.position
