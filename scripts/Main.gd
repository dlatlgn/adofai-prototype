extends Node2D

# ── 판정 창 (초) ──
const T_PERFECT: float = 0.055
const T_GOOD: float    = 0.110
const T_BAD: float     = 0.170

# ── 씬 노드 ──
var track: Track
var pair: PlanetPair
var cam: Camera2D

# UI
var _score_lbl: Label
var _combo_lbl: Label
var _judgment_lbl: Label
var _hint_lbl: Label
var _tile_info_lbl: Label
var _stage_lbl: Label

# ── 게임 상태 ──
var pivot_idx: int = 0
var running: bool = false
var _cleared: bool = false
var _j_timer: float = 0.0

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var perfect_count: int = 0
var good_count: int = 0
var bad_count: int = 0
var miss_count: int = 0

# 스테이지에서 로드
var _stage: Dictionary
var _bpm: float = 120.0
var _beat_time: float = 0.5

func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ── 스테이지 데이터 로드 ──
	_stage      = StageData.current()
	_bpm        = float(_stage["bpm"])
	_beat_time  = 60.0 / _bpm

	# ── Track ──
	track = Track.new()
	track.name = "Track"
	track.build_from_directions(_stage["path"])
	add_child(track)

	# ── PlanetPair ──
	pair = PlanetPair.new()
	pair.name = "PlanetPair"
	add_child(pair)

	track.position = Vector2.ZERO
	pair.position  = Vector2.ZERO

	# ── Camera ──
	cam = Camera2D.new()
	cam.name = "Cam"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed   = 5.0
	cam.position = track.tiles[0]
	add_child(cam)
	cam.make_current()

	# ── UI ──
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	_stage_lbl     = _mk_label(ui, Vector2(24, 18), 22, Color(0.85, 0.85, 1.0))
	_stage_lbl.text = "STAGE  %d.  %s   BPM %d" % [
		StageData.current_index + 1, _stage["name"], int(_bpm)
	]

	_score_lbl     = _mk_label(ui, Vector2(24, 52), 30, Color.WHITE)
	_combo_lbl     = _mk_label(ui, Vector2(24, 92), 40, Color.YELLOW)
	_tile_info_lbl = _mk_label(ui, Vector2(24, 144), 18, Color(0.7, 0.7, 0.85))

	_judgment_lbl = Label.new()
	_judgment_lbl.add_theme_font_size_override("font_size", 56)
	_judgment_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_lbl.size     = Vector2(vp.x, 100)
	_judgment_lbl.position = Vector2(0, vp.y * 0.14)
	ui.add_child(_judgment_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.text = "SPACE 리듬에 맞춰 눌러 다음 타일로!    |    ESC 메뉴로"
	_hint_lbl.add_theme_font_size_override("font_size", 18)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.modulate = Color(0.55, 0.55, 0.65)
	_hint_lbl.size     = Vector2(vp.x, 30)
	_hint_lbl.position = Vector2(0, vp.y - 40)
	ui.add_child(_hint_lbl)

	_update_ui()
	_ready_and_go()

func _mk_label(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	parent.add_child(l)
	return l

# 짧은 카운트인 후 시작
func _ready_and_go() -> void:
	_judgment_lbl.text     = "READY..."
	_judgment_lbl.modulate = Color(0.65, 0.80, 1.00)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree(): return
	_judgment_lbl.text     = "GO!"
	_judgment_lbl.modulate = Color(0.35, 1.00, 0.55)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree(): return
	_judgment_lbl.text = ""
	_start_next_rotation()

# ── 프레임 업데이트 ──
func _process(delta: float) -> void:
	if _j_timer > 0.0:
		_j_timer -= delta
		if _j_timer <= 0.0 and not _cleared:
			_judgment_lbl.text = ""

	# 자동 미스 : 회전자가 타겟을 T_BAD 만큼 지나쳤는데도 입력이 없으면
	if running and pair.elapsed > pair.beat_time + T_BAD:
		_register_miss()
		_advance()

	# 카메라 : 현재 피벗을 부드럽게 따라간다
	if cam != null and pair != null:
		cam.position = pair.pivot_pos

# ── 입력 ──
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event
	if ke.echo or not ke.pressed:
		return

	if ke.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")
		return

	if _cleared:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")
		return

	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_try_hit()

func _try_hit() -> void:
	if not running:
		return
	var diff: float     = pair.elapsed - pair.beat_time
	var abs_diff: float = absf(diff)

	if abs_diff <= T_PERFECT:
		_hit("PERFECT!", 300, Color.GOLD)
		perfect_count += 1
	elif abs_diff <= T_GOOD:
		_hit("GOOD", 100, Color.LIME_GREEN)
		good_count += 1
	elif abs_diff <= T_BAD:
		_hit("BAD", 30, Color.ORANGE)
		bad_count += 1
	else:
		_register_miss()
	_advance()

func _hit(text: String, pts: int, color: Color) -> void:
	combo     += 1
	max_combo  = maxi(max_combo, combo)
	score     += pts + combo * 10
	pair.trigger_landing_pulse()
	_show_judgment(text, color)
	_update_ui()

func _register_miss() -> void:
	combo = 0
	miss_count += 1
	_show_judgment("MISS", Color(1, 0.35, 0.35))
	_update_ui()

# ── 다음 타일로 진행 ──
func _advance() -> void:
	pivot_idx += 1
	pair.swap_roles()
	if pivot_idx >= track.tiles.size() - 1:
		_game_clear()
		return
	_start_next_rotation()

func _start_next_rotation() -> void:
	var pivot_pos: Vector2 = track.tiles[pivot_idx]
	track.set_current(pivot_idx)

	# 회전자의 시작 각도 = 피벗 → 이전 타일 방향
	var start_angle: float
	if pivot_idx == 0:
		var first: Vector2 = track.tiles[1] - track.tiles[0]
		start_angle = (-first).angle()
	else:
		var to_prev: Vector2 = track.tiles[pivot_idx - 1] - track.tiles[pivot_idx]
		start_angle = to_prev.angle()

	var to_next: Vector2 = track.tiles[pivot_idx + 1] - track.tiles[pivot_idx]
	var end_angle: float = to_next.angle()

	# CCW 회전량
	var delta: float = end_angle - start_angle
	while delta <= 0.001:
		delta += TAU

	# 180° 회전 = 1 비트. 시간 = 회전량 / PI * beat_time
	var duration: float = (delta / PI) * _beat_time

	pair.start_rotation(pivot_pos, start_angle, end_angle, duration)
	running = true
	_update_ui()

func _game_clear() -> void:
	running = false
	_cleared = true
	pair.stop()
	_judgment_lbl.text = "CLEAR!\n\nSCORE  %d   MAX COMBO  %d\nP:%d  G:%d  B:%d  M:%d\n\nENTER / SPACE 로 메뉴" % [
		score, max_combo, perfect_count, good_count, bad_count, miss_count
	]
	_judgment_lbl.modulate = Color.GOLD
	_j_timer = 99999.0

# ── UI ──
func _show_judgment(text: String, color: Color) -> void:
	if _cleared:
		return
	_judgment_lbl.text     = text
	_judgment_lbl.modulate = color
	_j_timer = 0.35

func _update_ui() -> void:
	_score_lbl.text = "SCORE  %d" % score
	_combo_lbl.text = "%d COMBO" % combo if combo >= 2 else ""
	if track != null:
		_tile_info_lbl.text = "TILE  %d / %d" % [pivot_idx + 1, track.tiles.size()]
