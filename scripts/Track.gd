class_name Track
extends Node2D

const TILE_DIST: float  = 90.0
const ROAD_WIDTH: float = 44.0
const JOINT_R: float    = ROAD_WIDTH * 0.55  # 관절 원 반지름 (도로보다 살짝 넓게)

var tiles: Array[Vector2] = []
var current_tile: int = 0

# path_dirs[i] : tile[i] -> tile[i+1] 방향 (라디안, 화면좌표: +y 아래)
func build_from_directions(path_dirs: Array) -> void:
	tiles.clear()
	tiles.append(Vector2.ZERO)
	for v in path_dirs:
		var d: float = float(v)
		var prev: Vector2 = tiles[tiles.size() - 1]
		tiles.append(prev + Vector2.RIGHT.rotated(d) * TILE_DIST)
	queue_redraw()

func set_current(idx: int) -> void:
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

# ── 렌더 : 도로처럼 연속된 리본으로 그린다 ─────────────────────────────────
func _draw() -> void:
	# 1. 리본 본체 : 인접 타일 간 굵은 선
	for i in range(tiles.size() - 1):
		draw_line(tiles[i], tiles[i + 1], _road_color(i), ROAD_WIDTH, true)

	# 2. 각 타일 위치의 둥근 관절 (모서리 부드럽게)
	for i in tiles.size():
		draw_circle(tiles[i], JOINT_R, _joint_color(i))

	# 3. 각 타일 중심에 작은 도트 (박자 기준점)
	for i in tiles.size():
		var col: Color = _dot_color(i)
		if col.a > 0.0:
			draw_circle(tiles[i], 4.0, col)

	# 4. 현재 피벗 강조 : 노란 원 + 링
	if current_tile >= 0 and current_tile < tiles.size():
		var p: Vector2 = tiles[current_tile]
		draw_circle(p, JOINT_R - 8.0, Color(1.00, 0.87, 0.30))
		draw_arc(p, JOINT_R + 3.0, 0.0, TAU, 64, Color(1.00, 0.95, 0.55), 3.0, true)

	# 5. 다음 착지 타일 강조 : 보라색 링
	if current_tile + 1 < tiles.size():
		var p: Vector2 = tiles[current_tile + 1]
		draw_arc(p, JOINT_R + 3.0, 0.0, TAU, 64, Color(0.95, 0.50, 1.00), 2.8, true)
		draw_circle(p, 6.0, Color(0.95, 0.50, 1.00, 0.85))

func _road_color(i: int) -> Color:
	# 세그먼트 i : tile[i] -> tile[i+1]
	if i < current_tile:
		return Color(0.13, 0.14, 0.20)   # 지나간 곳 : 어둡게
	elif i < current_tile + 3:
		return Color(0.42, 0.44, 0.62)   # 활성 구간
	else:
		return Color(0.30, 0.32, 0.46)   # 앞으로 갈 곳

func _joint_color(i: int) -> Color:
	if i < current_tile:
		return Color(0.13, 0.14, 0.20)
	elif i <= current_tile + 3:
		return Color(0.42, 0.44, 0.62)
	else:
		return Color(0.30, 0.32, 0.46)

func _dot_color(i: int) -> Color:
	if i == current_tile or i == current_tile + 1:
		return Color(0, 0, 0, 0)  # 피벗/다음은 별도 강조로 그리므로 스킵
	elif i < current_tile:
		return Color(1, 1, 1, 0.10)
	else:
		return Color(1, 1, 1, 0.35)
