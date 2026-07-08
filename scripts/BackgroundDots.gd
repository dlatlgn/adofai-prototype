class_name BackgroundDots
extends Node2D

# ── 스크린 좌표 기반 땡땡이 무늬 배경 ──
# CanvasLayer(layer=-1) 안에 배치 → 게임 월드 뒤에 렌더

const SPACING: float = 62.0    # 도트 간격
const R_BASE: float  = 2.4     # 기본 반지름
const R_ADD: float   = 2.6     # 펄스 시 확장량
const A_BASE: float  = 0.045   # 평상시 알파 (아주 흐림)
const A_PEAK: float  = 0.28    # 펄스 피크 알파

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

	var cols: int = int(viewport_size.x / SPACING) + 3
	var rows: int = int(viewport_size.y / SPACING) + 3
	var off_x: float = fmod(viewport_size.x, SPACING) * 0.5
	var off_y: float = fmod(viewport_size.y, SPACING) * 0.5

	# 짝수·홀수 행 교차 오프셋으로 폴카닷 패턴 (마름모 격자)
	for j in rows:
		var y: float = off_y + float(j) * SPACING
		var x_shift: float = SPACING * 0.5 if (j % 2 == 1) else 0.0
		for i in cols:
			var x: float = off_x + float(i) * SPACING + x_shift
			draw_circle(Vector2(x, y), r, col)
