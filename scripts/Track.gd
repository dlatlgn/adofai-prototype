class_name Track
extends Node2D

const TILE_DIST: float  = 90.0
const ROAD_WIDTH: float = 56.0
const JOINT_R: float    = ROAD_WIDTH * 0.58   # 관절 원 (도로보다 살짝 넓게 → 각진 이음매 커버)

var tiles: Array[Vector2] = []
var current_tile: int = 0

# 착지 잔광 : 최근 착지한 타일 위치의 확산 링
var _flashes: Array = []   # 각 항목 { pos: Vector2, age: float }
var _time: float = 0.0

func build_from_directions(path_dirs: Array) -> void:
	tiles.clear()
	tiles.append(Vector2.ZERO)
	for v in path_dirs:
		var d: float = float(v)
		var prev: Vector2 = tiles[tiles.size() - 1]
		tiles.append(prev + Vector2.RIGHT.rotated(d) * TILE_DIST)
	queue_redraw()

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
	# 1. 도로 리본
	for i in range(tiles.size() - 1):
		draw_line(tiles[i], tiles[i + 1], _road_color(i), ROAD_WIDTH, true)

	# 2. 관절 (둥근 이음매)
	for i in tiles.size():
		draw_circle(tiles[i], JOINT_R, _joint_color(i))

	# 3. 소도트 (박자 마커) — 지나온 곳은 그냥 흐리게
	for i in tiles.size():
		var col: Color = _dot_color(i)
		if col.a > 0.0:
			draw_circle(tiles[i], 4.5, col)

	# 5. 현재 피벗 강조 (노란 원 + 회전 링)
	if current_tile >= 0 and current_tile < tiles.size():
		var p: Vector2 = tiles[current_tile]
		var pulse_r: float = JOINT_R + 4.0 + sin(_time * 6.0) * 3.0
		draw_circle(p, JOINT_R - 6.0, Color(1.00, 0.87, 0.30))
		draw_arc(p, pulse_r, 0.0, TAU, 64, Color(1.00, 0.95, 0.55), 3.2, true)

	# 6. 다음 착지 타일 (보라)
	if current_tile + 1 < tiles.size():
		var p: Vector2 = tiles[current_tile + 1]
		draw_arc(p, JOINT_R + 3.0, 0.0, TAU, 64, Color(0.95, 0.50, 1.00), 3.0, true)
		draw_circle(p, 8.0, Color(0.95, 0.50, 1.00, 0.9))

	# 7. 착지 순간 확장 링
	for f in _flashes:
		var a: float = f["age"] as float
		var t: float = a / 0.75
		var r: float = JOINT_R + t * 55.0
		var alpha: float = pow(1.0 - t, 1.5) * 0.85
		var w: float = 5.0 * (1.0 - t) + 1.0
		draw_arc(f["pos"], r, 0.0, TAU, 56, Color(1.0, 0.95, 0.55, alpha), w, true)

	# 8. 결승선 마커 (마지막 타일)
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
		# 지나온 : 뒤로 갈수록 더 어둡게 페이드
		var dist: int = current_tile - i
		var fade: float = maxf(0.10, 0.25 - dist * 0.015)
		return Color(fade, fade, fade * 1.1)
	elif i < current_tile + 3:
		return Color(0.45, 0.47, 0.66)   # 활성 구간
	else:
		return Color(0.32, 0.34, 0.50)   # 앞으로 갈 곳

func _joint_color(i: int) -> Color:
	if i < current_tile:
		var dist: int = current_tile - i
		var fade: float = maxf(0.10, 0.25 - dist * 0.015)
		return Color(fade, fade, fade * 1.1)
	elif i <= current_tile + 3:
		return Color(0.45, 0.47, 0.66)
	else:
		return Color(0.32, 0.34, 0.50)

func _dot_color(i: int) -> Color:
	if i == current_tile or i == current_tile + 1 or i == tiles.size() - 1:
		return Color(0, 0, 0, 0)  # 별도 강조되므로 스킵
	elif i < current_tile:
		return Color(1, 1, 1, 0.10)  # 지나온 : 그냥 흐린 흰 도트
	else:
		return Color(1, 1, 1, 0.40)
