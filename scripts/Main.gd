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
var _flash_rect: ColorRect

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

# 화면 플래시
var _flash_alpha: float = 0.0
var _flash_color: Color = Color.WHITE

# 카메라 셰이크
var _shake_time: float = 0.0
var _shake_intensity: float = 0.0

# 카메라 회전 임펄스 (난이도 3+)
const CAM_IMPULSE_DUR: float = 0.32
var _rot_target: float = 0.0
var _rot_time: float = 0.0

# 카메라 줌 임펄스 (난이도 4+)
var _zoom_target: float = 1.0
var _zoom_time: float = 0.0

# 상시 웨이브 (난이도 5)
var _time: float = 0.0

# 스테이지 데이터
var _stage: Dictionary
var _bpm: float = 120.0
var _beat_time: float = 0.5
var _difficulty: int = 1
var _diff_mult: float = 1.0

func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ── 검은 배경 ──
	RenderingServer.set_default_clear_color(Color.BLACK)

	# ── 스테이지 로드 ──
	_stage      = StageData.current()
	_bpm        = float(_stage["bpm"])
	_beat_time  = 60.0 / _bpm
	_difficulty = int(_stage.get("difficulty", 1))
	# 난이도별 이펙트 세기 배수 (1.0 → 2.4)
	_diff_mult  = 1.0 + float(_difficulty - 1) * 0.35

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

	# 화면 플래시 오버레이 (판정용)
	_flash_rect = ColorRect.new()
	_flash_rect.size = vp
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash_rect)

	_stage_lbl = _mk_label(ui, Vector2(24, 18), 22, Color(0.85, 0.85, 1.0))
	_stage_lbl.text = "STAGE  %d.  %s   BPM %d" % [
		StageData.current_index + 1, _stage["name"], int(_bpm)
	]

	_score_lbl     = _mk_label(ui, Vector2(24, 52), 30, Color.WHITE)
	_combo_lbl     = _mk_label(ui, Vector2(24, 92), 42, Color.YELLOW)
	_tile_info_lbl = _mk_label(ui, Vector2(24, 148), 18, Color(0.7, 0.7, 0.85))

	_judgment_lbl = Label.new()
	_judgment_lbl.add_theme_font_size_override("font_size", 60)
	_judgment_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_lbl.size     = Vector2(vp.x, 110)
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
	_trigger_flash(Color(0.35, 1.0, 0.55), 0.35)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree(): return
	_judgment_lbl.text = ""
	_start_next_rotation()

# ── 프레임 업데이트 ──
func _process(delta: float) -> void:
	_time += delta

	if _j_timer > 0.0:
		_j_timer -= delta
		if _j_timer <= 0.0 and not _cleared:
			_judgment_lbl.text = ""

	# 자동 미스 : 타겟 도달 즉시 (잔류 시간 삭제)
	if running and pair.elapsed > pair.beat_time:
		_register_miss()
		_advance()

	# 카메라 팔로우 + 셰이크
	if cam != null and pair != null:
		cam.position = pair.pivot_pos
		if _shake_time > 0.0:
			_shake_time -= delta
			cam.offset = Vector2(
				randf_range(-1, 1) * _shake_intensity,
				randf_range(-1, 1) * _shake_intensity
			)
			if _shake_time <= 0.0:
				cam.offset = Vector2.ZERO
		else:
			cam.offset = Vector2.ZERO

		# 카메라 회전 : 임펄스(감쇠) + 난이도 5의 상시 웨이브
		var impulse_rot: float = 0.0
		if _rot_time > 0.0:
			_rot_time = maxf(0.0, _rot_time - delta)
			var frac: float = _rot_time / CAM_IMPULSE_DUR
			impulse_rot = _rot_target * frac * frac
		var wobble: float = 0.0
		if _difficulty >= 5:
			wobble = sin(_time * 2.4) * 0.015
		cam.rotation = impulse_rot + wobble

		# 카메라 줌 임펄스 감쇠 (기본 1.0으로 복귀)
		if _zoom_time > 0.0:
			_zoom_time = maxf(0.0, _zoom_time - delta)
			var zf: float = _zoom_time / CAM_IMPULSE_DUR
			var z: float = 1.0 + (_zoom_target - 1.0) * zf * zf
			cam.zoom = Vector2(z, z)
			if _zoom_time <= 0.0:
				cam.zoom = Vector2.ONE

	# 화면 플래시 페이드
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 3.5)
		_flash_rect.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_alpha)

# ── 입력 ──
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event
	if ke.echo or not ke.pressed:
		return

	if ke.keycode == KEY_ESCAPE:
		RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.09))
		get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")
		return

	if _cleared:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.09))
			get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")
		return

	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_try_hit()

func _try_hit() -> void:
	if not running:
		return
	var diff: float     = pair.elapsed - pair.beat_time
	# 자동 미스 직후 다음 회전으로 넘어간 상황에서 늦은 입력이 이중 진행을 일으키지 않도록,
	# 판정창 밖의 극단적 조기 입력은 무시.
	if diff < -T_BAD:
		return
	var abs_diff: float = absf(diff)

	if abs_diff <= T_PERFECT:
		_hit("PERFECT!", 300, Color.GOLD)
		perfect_count += 1
		_trigger_flash(Color(1.0, 0.9, 0.4), 0.22 * _diff_mult)
		_landing_cam_impulse(1.0)
	elif abs_diff <= T_GOOD:
		_hit("GOOD", 100, Color.LIME_GREEN)
		good_count += 1
		_trigger_flash(Color(0.4, 1.0, 0.5), 0.14 * _diff_mult)
		_landing_cam_impulse(0.7)
	elif abs_diff <= T_BAD:
		_hit("BAD", 30, Color.ORANGE)
		bad_count += 1
		_trigger_flash(Color(1.0, 0.6, 0.3), 0.10 * _diff_mult)
		_landing_cam_impulse(0.4)
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
	# 미스 : 큰 적색 플래시 + 강한 셰이크 (난이도 스케일)
	_trigger_flash(Color(1.0, 0.2, 0.2), 0.22 * _diff_mult)
	_shake_intensity = 6.0 * _diff_mult
	_shake_time      = 0.28
	# 회전 임펄스도 더 강하게
	if _difficulty >= 2:
		_rot_target = randf_range(-1, 1) * 0.06 * _diff_mult
		_rot_time   = CAM_IMPULSE_DUR

# ── 착지 시 카메라 임펄스 (난이도별 확장) ──
# strength = 판정에 따른 세기 배수 (PERFECT=1.0, GOOD=0.7, BAD=0.4)
func _landing_cam_impulse(strength: float) -> void:
	if _difficulty <= 1:
		return
	# 난이도 2+ : 짧은 셰이크
	_shake_intensity = 2.2 * float(_difficulty - 1) * strength
	_shake_time      = 0.12
	# 난이도 3+ : 회전 임펄스
	if _difficulty >= 3:
		var mag: float = 0.032 * float(_difficulty - 2) * strength
		_rot_target = randf_range(-1, 1) * mag
		_rot_time   = CAM_IMPULSE_DUR
	# 난이도 4+ : 줌 임펄스 (살짝 확대)
	if _difficulty >= 4:
		_zoom_target = 1.0 + 0.025 * float(_difficulty - 3) * strength
		_zoom_time   = CAM_IMPULSE_DUR

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

	var start_angle: float
	if pivot_idx == 0:
		var first: Vector2 = track.tiles[1] - track.tiles[0]
		start_angle = (-first).angle()
	else:
		var to_prev: Vector2 = track.tiles[pivot_idx - 1] - track.tiles[pivot_idx]
		start_angle = to_prev.angle()

	var to_next: Vector2 = track.tiles[pivot_idx + 1] - track.tiles[pivot_idx]
	var end_angle: float = to_next.angle()

	var delta: float = end_angle - start_angle
	while delta <= 0.001:
		delta += TAU

	var duration: float = (delta / PI) * _beat_time

	pair.start_rotation(pivot_pos, start_angle, end_angle, duration)
	running = true
	_update_ui()

# ── 클리어 → 폭발 이펙트 ──
func _game_clear() -> void:
	running = false
	_cleared = true
	pair.stop()

	track.set_current(track.tiles.size() - 1)

	# 마지막 타일 좌표에서 폭발 (swap_roles 후이므로 role은 신뢰 X)
	var end_pos: Vector2 = track.tiles[track.tiles.size() - 1]
	# 난이도별 폭발 규모
	var gold_count: int = int(120.0 * _diff_mult)
	var white_count: int = int(40.0 * _diff_mult)
	_spawn_explosion(end_pos, Color(1.00, 0.85, 0.30), gold_count)
	_spawn_explosion(end_pos, Color(1.0, 1.0, 1.0), white_count)
	# 고난이도는 추가로 컬러 스파크 (핑크/시안)
	if _difficulty >= 3:
		_spawn_explosion(end_pos, Color(1.0, 0.4, 0.9), int(50 * _diff_mult))
	if _difficulty >= 4:
		_spawn_explosion(end_pos, Color(0.4, 0.9, 1.0), int(50 * _diff_mult))
	# 카메라 셰이크 (난이도 스케일)
	_shake_intensity = 12.0 * _diff_mult
	_shake_time      = 0.5 + _diff_mult * 0.1
	# 회전 임펄스 강하게
	_rot_target = randf_range(-1, 1) * 0.08 * _diff_mult
	_rot_time   = CAM_IMPULSE_DUR * 1.4
	# 화면 플래시
	_trigger_flash(Color(1.0, 0.9, 0.5), 0.55 * _diff_mult)

	_judgment_lbl.text = "★  CLEAR  ★\n\nSCORE  %d   MAX COMBO  %d\nP:%d  G:%d  B:%d  M:%d\n\nENTER / SPACE 로 메뉴" % [
		score, max_combo, perfect_count, good_count, bad_count, miss_count
	]
	_judgment_lbl.modulate = Color.GOLD
	_j_timer = 99999.0

func _spawn_explosion(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position                = pos
	p.emitting                = true
	p.one_shot                = true
	p.explosiveness           = 1.0
	p.amount                  = amount
	p.lifetime                = 1.5
	p.direction               = Vector2.UP
	p.spread                  = 180.0
	p.initial_velocity_min    = 220.0
	p.initial_velocity_max    = 620.0
	p.gravity                 = Vector2(0, 350)
	p.scale_amount_min        = 4.0
	p.scale_amount_max        = 9.0
	p.color                   = color
	p.damping_min             = 40.0
	p.damping_max             = 120.0
	add_child(p)
	# 파티클 수명 지나면 자동 삭제
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(p.queue_free)

# ── 이펙트 헬퍼 ──
func _trigger_flash(color: Color, alpha: float) -> void:
	_flash_color = color
	_flash_alpha = maxf(_flash_alpha, alpha)

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
