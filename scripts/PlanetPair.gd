class_name PlanetPair
extends Node2D

const ARM_LENGTH: float = 90.0  # Track.TILE_DIST 와 동일

var fire: Planet
var ice: Planet

var fire_is_pivot: bool = true

# 이번 비트의 회전 상태
var pivot_pos: Vector2 = Vector2.ZERO
var start_angle: float = PI    # 회전자 시작 각도 (피벗 기준)
var rotation_delta: float = PI  # 이번에 CCW로 회전할 총량 (양수)
var beat_time: float = 0.5      # 이번 회전에 걸리는 시간 (초)
var elapsed: float = 0.0
var running: bool = false

func _ready() -> void:
	fire = Planet.new()
	fire.is_fire = true
	add_child(fire)

	ice = Planet.new()
	ice.is_fire = false
	add_child(ice)

	_update_positions(start_angle)

func start_rotation(new_pivot: Vector2, from_angle: float, to_angle: float, duration: float) -> void:
	pivot_pos   = new_pivot
	start_angle = from_angle
	# 항상 CCW(양수) 방향 회전
	var delta: float = to_angle - from_angle
	while delta <= 0.001:
		delta += TAU
	rotation_delta = delta
	beat_time      = duration
	elapsed        = 0.0
	running        = true
	_update_positions(start_angle)
	queue_redraw()

func _draw() -> void:
	if not running:
		return
	# 궤도 원 (도로 위, 행성 아래에 렌더링됨)
	draw_arc(pivot_pos, ARM_LENGTH, 0.0, TAU, 72, Color(1, 1, 1, 0.13), 1.8, true)

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

func _update_positions(angle: float) -> void:
	var rotator_pos: Vector2 = pivot_pos + Vector2.RIGHT.rotated(angle) * ARM_LENGTH
	if fire_is_pivot:
		fire.position = pivot_pos
		ice.position  = rotator_pos
	else:
		ice.position  = pivot_pos
		fire.position = rotator_pos

func trigger_landing_pulse() -> void:
	# 방금 착지한 (회전하고 있던) 행성에 이펙트
	if fire_is_pivot:
		ice.trigger_pulse()
	else:
		fire.trigger_pulse()
