class_name Track
extends Node2D

const TILE_DIST: float  = 90.0
const ROAD_WIDTH: float = 56.0
const JOINT_R: float    = ROAD_WIDTH * 0.58   # 관절 원 (도로보다 살짝 넓게 → 각진 이음매 커버)

# ── 발판 종류 ──
const T_NORMAL: int     = 0
const T_SPEED_UP: int   = 1   # BPM × 1.5 (초록)
const T_SPEED_DOWN: int = 2   # BPM ÷ 1.5 (빨강)
const T_TWIRL: int      = 3   # 회전 방향 반전 (시안)

# 발판 색상
const COL_SPEED_UP: Color   = Color(0.35, 1.00, 0.45)
const COL_SPEED_DOWN: Color = Color(1.00, 0.40, 0.45)
const COL_TWIRL: Color      = Color(0.35, 1.00, 1.00)

var tiles: Array[Vector2] = []
var tile_types: Array[int] = []
var current_tile: int = 0

# 착지 잔광 : 최근 착지한 타일 위치의 확산 링
var _flashes: Array = []   # 각 항목 { pos: Vector2, age: float }
var _time: float = 0.0

func build_from_directions(path_dirs: Array) -> void:
	tiles.clear()
	tile_types.clear()
	tiles.append(Vector2.ZERO)
	tile_types.append(T_NORMAL)
	for v in path_dirs:
		var d: float = float(v)
		var prev: Vector2 = tiles[tiles.size() - 1]
		tiles.append(prev + Vector2.RIGHT.rotated(d) * TILE_DIST)
		tile_types.append(T_NORMAL)
	queue_redraw()

# specials : { tile_index: type_int } 사전으로 특수 발판 지정
func set_specials(specials: Dictionary) -> void:
	for k in specials.keys():
		var idx: int = int(k)
		var t: int = int(specials[k])
		if idx >= 0 and idx < tile_types.size():
			tile_types[idx] = t
	queue_redraw()

func type_at(idx: int) -> int:
	if idx < 0 or idx >= tile_types.size():
		return T_NORMAL
	return tile_types[idx]

func set_current(idx: int) -> void:
	# idx가 진행되면 새 타일에 착지한 것 → 확장 링 스폰
	if idx > current_tile and idx > 0 and idx < tiles.size():
		_flashes.append({"pos": tiles[idx], "age": 0.0})
	current_tile = idx
	queue_redraw()

func bounds() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var mn: Vector2 = tiles[0]
	var mx: Vector2 = tiles[0]
	for p in tiles:
		mn.x = minf(mn.x, p.x); mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x); mx.y = maxf(mx.y, p.y)
	return Rect2(mn, mx - mn)

func _process(delta: float) -> void:
	_time += delta
	# 잔광 노후화
	var alive: Array = []
	for f in _flashes:
		f["age"] = f["age"] + delta
		if f["age"] < 0.75:
			alive.append(f)
	_flashes = alive
	queue_redraw()

func _draw() -> void:
	# 1. 지나온 관절 뒤에 8층 그라데이션 흰빛 글로우
	#    최대 반경 JOINT_R + 66 ≈ 98px > TILE_DIST(90) → 인접 타일 글로우 오버랩 → 동화
	for i in range(current_tile):
		var pos: Vector2 = tiles[i]
		var dist: int = current_tile - i
		var glow_base: float = maxf(0.10, 0.60 - dist * 0.018)
		for layer_i in range(8):
			var t: float = float(layer_i) / 7.0     # 0(중심) → 1(외곽)
			var r: float = JOINT_R + 2.0 + t * 64.0
			var falloff: float = pow(1.0 - t, 1.7)   # 부드러운 감쇠
			var alpha: float = glow_base * falloff * 0.30
			draw_circle(pos, r, Color(1, 1, 1, alpha))

	# 2. 지나온 도로 뒤에 넓은 흰빛 이중 트레일 (인접 타일 글로우와 이어짐)
	for i in range(current_tile):
		if i + 1 < tiles.size():
			var d: int = current_tile - i
			var base_a: float = maxf(0.06, 0.35 - d * 0.018)
			draw_line(tiles[i], tiles[i + 1], Color(1, 1, 1, base_a * 0.28), ROAD_WIDTH + 28.0, true)
			draw_line(tiles[i], tiles[i + 1], Color(1, 1, 1, base_a * 0.50), ROAD_WIDTH + 14.0, true)

	# 3. 도로 리본
	for i in range(tiles.size() - 1):
		draw_line(tiles[i], tiles[i + 1], _road_color(i), ROAD_WIDTH, true)

	# 4. 관절 (둥근 이음매)
	for i in tiles.size():
		draw_circle(tiles[i], JOINT_R, _joint_color(i))

	# 5. 소도트 (박자 마커)
	for i in tiles.size():
		var col: Color = _dot_color(i)
		if col.a > 0.0:
			draw_circle(tiles[i], 4.5, col)

	# 6. 현재 피벗 강조 (노란 원 + 회전 링)
	if current_tile >= 0 and current_tile < tiles.size():
		var p: Vector2 = tiles[current_tile]
		var pulse_r: float = JOINT_R + 4.0 + sin(_time * 6.0) * 3.0
		draw_circle(p, JOINT_R - 6.0, Color(1.00, 0.87, 0.30))
		draw_arc(p, pulse_r, 0.0, TAU, 64, Color(1.00, 0.95, 0.55), 3.2, true)

	# 7. 다음 착지 타일 (보라)
	if current_tile + 1 < tiles.size():
		var p: Vector2 = tiles[current_tile + 1]
		draw_arc(p, JOINT_R + 3.0, 0.0, TAU, 64, Color(0.95, 0.50, 1.00), 3.0, true)
		draw_circle(p, 8.0, Color(0.95, 0.50, 1.00, 0.9))

	# 7.5 특수 발판 시각화 (외곽 컬러 링 + 아이콘)
	for i in tile_types.size():
		var t: int = tile_types[i]
		if t == T_NORMAL:
			continue
		_draw_special(i, t)

	# 8. 착지 순간 확장 링
	for f in _flashes:
		var a: float = f["age"] as float
		var t: float = a / 0.75
		var r: float = JOINT_R + t * 55.0
		var alpha: float = pow(1.0 - t, 1.5) * 0.85
		var w: float = 5.0 * (1.0 - t) + 1.0
		draw_arc(f["pos"], r, 0.0, TAU, 56, Color(1.0, 0.95, 0.55, alpha), w, true)

	# 9. 결승선 마커 (마지막 타일)
	if tiles.size() >= 2:
		var final: Vector2 = tiles[tiles.size() - 1]
		var is_at_end: bool = current_tile >= tiles.size() - 1
		var accent: Color = Color(1.0, 0.85, 0.30) if is_at_end else Color(0.35, 1.00, 0.55)

		# 팽창하는 3중 링
		for i in 3:
			var phase: float = fmod(_time * 1.4 + float(i) / 3.0, 1.0)
			var r2: float = JOINT_R * 0.9 + phase * 62.0
			var alpha2: float = (1.0 - phase) * 0.55
			draw_arc(final, r2, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, alpha2), 3.5, true)

		# 중심 마커 + 회전하는 점들
		draw_circle(final, JOINT_R * 0.55, accent)
		draw_arc(final, JOINT_R * 0.7, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)
		for i in 8:
			var a2: float = TAU * float(i) / 8.0 + _time * 1.2
			var pt: Vector2 = final + Vector2.RIGHT.rotated(a2) * (JOINT_R * 1.5)
			draw_circle(pt, 3.5, Color(accent.r, accent.g, accent.b, 0.85))

# ── 색상 헬퍼 ──
func _road_color(i: int) -> Color:
	if i < current_tile:
		# 지나온 : 흰빛으로 빛나되 거리에 따라 페이드
		var dist: int = current_tile - i
		var fade: float = maxf(0.35, 0.90 - dist * 0.03)
		return Color(fade, fade, fade * 1.02)
	elif i < current_tile + 3:
		return Color(0.45, 0.47, 0.66)
	else:
		return Color(0.32, 0.34, 0.50)

func _joint_color(i: int) -> Color:
	if i < current_tile:
		var dist: int = current_tile - i
		var fade: float = maxf(0.40, 0.95 - dist * 0.03)
		return Color(fade, fade, fade * 1.02)
	elif i <= current_tile + 3:
		return Color(0.45, 0.47, 0.66)
	else:
		return Color(0.32, 0.34, 0.50)

func _dot_color(i: int) -> Color:
	if i == current_tile or i == current_tile + 1 or i == tiles.size() - 1:
		return Color(0, 0, 0, 0)
	elif i < current_tile:
		return Color(0, 0, 0, 0)  # 관절 자체가 이미 흰빛 → 도트 생략
	else:
		return Color(1, 1, 1, 0.40)

# ── 특수 발판 렌더 : 컬러 링 + 심볼 ──
func _draw_special(idx: int, t: int) -> void:
	var pos: Vector2 = tiles[idx]
	var col: Color
	match t:
		T_SPEED_UP:   col = COL_SPEED_UP
		T_SPEED_DOWN: col = COL_SPEED_DOWN
		T_TWIRL:      col = COL_TWIRL
		_: return

	# 은은한 맥동
	var pulse: float = 1.0 + sin(_time * 3.5 + float(idx) * 0.4) * 0.08
	var ring_r: float = (JOINT_R + 11.0) * pulse

	# 외곽 컬러 링 (2겹)
	draw_arc(pos, ring_r,       0.0, TAU, 56, Color(col.r, col.g, col.b, 0.95), 3.4, true)
	draw_arc(pos, ring_r + 5.0, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.35), 1.6, true)

	# 심볼
	match t:
		T_SPEED_UP:
			# 오른쪽 화살표 두 개 >>
			_draw_chevron(pos + Vector2(-9, 0), Vector2.RIGHT, col, 6.0)
			_draw_chevron(pos + Vector2( 3, 0), Vector2.RIGHT, col, 6.0)
		T_SPEED_DOWN:
			# 왼쪽 화살표 두 개 <<
			_draw_chevron(pos + Vector2( 9, 0), Vector2.LEFT, col, 6.0)
			_draw_chevron(pos + Vector2(-3, 0), Vector2.LEFT, col, 6.0)
		T_TWIRL:
			# 원형 회살표 (아크 + 화살촉)
			var r_ic: float = JOINT_R * 0.42
			draw_arc(pos, r_ic, 0.5, TAU - 0.25, 32, col, 2.8, true)
			var tip: Vector2 = pos + Vector2.RIGHT.rotated(0.5) * r_ic
			draw_line(tip, tip + Vector2(-5, -6).rotated(0.5), col, 2.4, true)
			draw_line(tip, tip + Vector2( 4, -3).rotated(0.5), col, 2.4, true)

func _draw_chevron(pos: Vector2, dir: Vector2, col: Color, size: float) -> void:
	# > 모양 : 두 개의 대각선
	var f: Vector2 = dir.normalized() * size
	var s: Vector2 = Vector2(-f.y, f.x) * 0.6   # 수직 성분
	draw_line(pos - f - s, pos + f, col, 2.6, true)
	draw_line(pos + f, pos - f + s, col, 2.6, true)
