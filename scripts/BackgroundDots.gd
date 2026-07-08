class_name BackgroundDots
extends Node2D

# ── 스크린 좌표 기반 45° 회전 폴카닷 배경 ──
# CanvasLayer(layer=-1) 안에 배치 → 게임 월드 뒤에 렌더

const SPACING: float = 66.0     # 도트 간격 (diagonal 축 기준)
const R_BASE: float  = 3.4      # 기본 반지름 (확대)
const R_ADD: float   = 3.0      # 펄스 시 확장량
const A_BASE: float  = 0.05     # 평상시 알파
const A_PEAK: float  = 0.30     # 펄스 피크 알파

var viewport_size: Vector2 = Vector2(1152, 648)
var _pulse: float = 0.0

func trigger_pulse(strength: float) -> void:
	_pulse = maxf(_pulse, clampf(strength, 0.0, 1.0))
	queue_redraw()

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.6)
		queue_redraw()

func _draw() -> void:
	var eased: float = _pulse * _pulse
	var a: float = A_BASE + eased * (A_PEAK - A_BASE)
	var r: float = R_BASE + _pulse * R_ADD
	var col := Color(1.0, 1.0, 1.0, a)

	# 45° 회전 격자 축 (다이아몬드 배치)
	const ROOT2_HALF: float = 0.7071067811865476
	var s: float = SPACING
	var ax: Vector2 = Vector2(s * ROOT2_HALF,  s * ROOT2_HALF)
	var ay: Vector2 = Vector2(-s * ROOT2_HALF, s * ROOT2_HALF)

	# 뷰포트 대각선을 덮을 만큼의 격자 범위
	var half_diag: float = viewport_size.length() * 0.5 + SPACING
	var reach: int = int(half_diag / SPACING) + 2
	var center: Vector2 = viewport_size * 0.5

	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var pos: Vector2 = center + ax * float(i) + ay * float(j)
			# 뷰포트 밖은 스킵 (약간의 여유)
			if pos.x < -SPACING or pos.x > viewport_size.x + SPACING \
			or pos.y < -SPACING or pos.y > viewport_size.y + SPACING:
				continue
			draw_circle(pos, r, col)
