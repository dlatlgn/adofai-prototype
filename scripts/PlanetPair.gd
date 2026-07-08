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

func _ready() -> void:
	fire = Planet.new()
	fire.is_fire = true
	add_child(fire)

	ice = Planet.new()
	ice.is_fire = false
	add_child(ice)

	_update_positions(start_angle)
	_reset_trails()

func start_rotation(new_pivot: Vector2, from_angle: float, to_angle: float, duration: float) -> void:
	pivot_pos   = new_pivot
	start_angle = from_angle
	var delta: float = to_angle - from_angle
	while delta <= 0.001:
		delta += TAU
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

	# 잔상 : 오래된 것부터 그리기(뒤에 최신)
	var fire_col: Color = Color(1.00, 0.35, 0.10)
	var ice_col: Color  = Color(0.30, 0.72, 1.00)
	for i in TRAIL_LEN:
		var age: float   = 1.0 - float(i) / float(TRAIL_LEN - 1)   # 0=newest, 1=oldest
		var alpha: float = pow(1.0 - age, 1.6) * 0.55
		var r_scale: float = 1.0 - age * 0.55
		draw_circle(_fire_trail[i], fire.radius * r_scale * 0.85, Color(fire_col.r, fire_col.g, fire_col.b, alpha))
		draw_circle(_ice_trail[i],  ice.radius  * r_scale * 0.85, Color(ice_col.r,  ice_col.g,  ice_col.b,  alpha))

func trigger_landing_pulse() -> void:
	if fire_is_pivot:
		ice.trigger_pulse()
	else:
		fire.trigger_pulse()

# 현재 회전자(=피벗이 아닌 쪽) 위치
func rotator_position() -> Vector2:
	return ice.position if fire_is_pivot else fire.position
