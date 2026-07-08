extends Node2D

# ══════════════════════════════════════════════════════════════════════
#  얼불춤 판정 시스템 (ADOFAI 기반)
# ══════════════════════════════════════════════════════════════════════
#
#  각도-ms 이중 판정 : 둘 중 관대한 쪽을 채택
#  · 정확     : ±30° 또는 ±25ms
#  · 빠름/느림 : ±45° 또는 ±30ms
#  · 빠름!/느림! : ±60° 또는 ±40ms
#  · 빠름!! : 위보다 더 빠름 → 착지 X, 회전 유지, 과부하 게이지 채움
#  · 느림!! : 위보다 더 느림 → 죽음 (실패 방지 ON 시 놓침... 표시 후 자동 진행)
#  · 과부하  : 과부하 게이지 만렙 도달
#
#  콤보 = 정확 판정만 카운트 (그 외 즉시 리셋)
#  정확도(%) = 정확×0.01 + (정확+빠름+느림)×100 / 전체
# ══════════════════════════════════════════════════════════════════════

enum J {
	PERFECT,      # 정확
	E_PERFECT,    # 빠름 (조기)
	L_PERFECT,    # 느림 (지연)
	EARLY,        # 빠름!
	LATE,         # 느림!
	EARLY_2,      # 빠름!! : 착지 실패
	LATE_2,       # 느림!! : 죽음
	MISS,         # 놓침... : 실패 방지 시 대체 라벨
	OVERLOAD,     # 과부하...
}

# 판정 임계값
const T_PERFECT_MS: float  = 0.025
const T_LPERFECT_MS: float = 0.030
const T_LATE_MS: float     = 0.040

const T_PERFECT_DEG: float  = 30.0
const T_LPERFECT_DEG: float = 45.0
const T_LATE_DEG: float     = 60.0

# 실패 방지 (놓침/과부하가 게임오버 대신 라벨 표시로 처리됨)
const FAILURE_PREVENTION: bool = true

# 과부하 게이지
const OVERLOAD_MAX: float      = 100.0
const OVERLOAD_ADD_E2: float   = 32.0   # 빠름!! 발생 시 증가량
const OVERLOAD_ADD_MISS: float = 40.0   # 놓침... 발생 시 증가량
# 감소 속도 : BPM * 이 계수 per sec (BPM 120 → 44/s, BPM 180 → 66/s)
const OVERLOAD_DRAIN_MULT: float = 0.37

# 판정 색상
const COL_PERFECT: Color   = Color(1.00, 0.40, 0.80)
const COL_E_PERFECT: Color = Color(0.35, 0.85, 1.00)
const COL_L_PERFECT: Color = Color(1.00, 0.85, 0.45)
const COL_EARLY: Color     = Color(0.45, 0.55, 1.00)
const COL_LATE: Color      = Color(1.00, 0.55, 0.20)
const COL_EARLY_2: Color   = Color(0.95, 0.40, 0.55)
const COL_LATE_2: Color    = Color(0.95, 0.30, 0.30)
const COL_MISS: Color      = Color(0.90, 0.30, 0.30)
const COL_OVERLOAD: Color  = Color(1.00, 0.20, 0.20)

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
var _acc_lbl: Label
var _stage_lbl: Label
var _flash_rect: ColorRect
var _ov_label_lbl: Label
var _ov_bg: ColorRect
var _ov_fill: ColorRect
const OV_BAR_W: float = 200.0
const OV_BAR_H: float = 8.0

# 배경 땡땡이
var _bg_dots: BackgroundDots

# 판정 팝업 (공 뒤에 뜨는 필기체 소형 라벨)
var _popup: JudgmentPopup

# ── 게임 상태 ──
var pivot_idx: int = 0
var running: bool = false
var _cleared: bool = false
var _j_timer: float = 0.0

var score: int = 0
var combo: int = 0
var max_combo: int = 0

# 판정 카운터 (9종)
var perfect_count: int   = 0
var e_perfect_count: int = 0
var l_perfect_count: int = 0
var early_count: int     = 0
var late_count: int      = 0
var early2_count: int    = 0
var miss_count: int      = 0    # Late!! / 놓침...
var overload_count: int  = 0

# 과부하
var overload_gauge: float = 0.0

# 화면 플래시
var _flash_alpha: float = 0.0

# 카메라 셰이크
var _shake_time: float = 0.0
var _shake_intensity: float = 0.0

# 카메라 회전/줌 임펄스
const CAM_IMPULSE_DUR: float = 0.32
var _rot_target: float = 0.0
var _rot_time: float = 0.0
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

# 특수 발판 상태
var _bpm_mult: float = 1.0     # 누적 BPM 배수 (SPEED_UP/DOWN)
var _rot_dir: int = 1          # 1 = CCW, -1 = CW (TWIRL로 반전)
var _effect_lbl: Label

# ══════════════════════════════════════════════════════════════════════
#  초기화
# ══════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size

	RenderingServer.set_default_clear_color(Color.BLACK)

	# 배경 땡땡이
	var bg_layer := CanvasLayer.new()
	bg_layer.name  = "BG"
	bg_layer.layer = -1
	add_child(bg_layer)
	_bg_dots = BackgroundDots.new()
	_bg_dots.viewport_size = vp
	bg_layer.add_child(_bg_dots)

	# 스테이지 로드
	_stage      = StageData.current()
	_bpm        = float(_stage["bpm"])
	_beat_time  = 60.0 / _bpm
	_difficulty = int(_stage.get("difficulty", 1))
	_diff_mult  = 1.0 + float(_difficulty - 1) * 0.35

	# Track
	track = Track.new()
	track.name = "Track"
	track.build_from_directions(_stage["path"])
	# 특수 발판 지정 (있다면)
	if _stage.has("specials"):
		track.set_specials(_stage["specials"])
	add_child(track)

	# 판정 팝업 : PlanetPair보다 먼저 add → Z-order에서 공 뒤에 렌더
	_popup = JudgmentPopup.new()
	_popup.name = "JudgmentPopup"
	add_child(_popup)

	# PlanetPair
	pair = PlanetPair.new()
	pair.name = "PlanetPair"
	add_child(pair)

	track.position = Vector2.ZERO
	pair.position  = Vector2.ZERO

	# Camera
	cam = Camera2D.new()
	cam.name = "Cam"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed   = 5.0
	cam.position = track.tiles[0]
	add_child(cam)
	cam.make_current()

	# UI
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	_flash_rect = ColorRect.new()
	_flash_rect.size = vp
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash_rect)

	_stage_lbl = _mk_label(ui, Vector2(24, 18), 22, Color(0.85, 0.85, 1.0))
	_stage_lbl.text = "STAGE  %d.  %s   BPM %d" % [
		StageData.current_index + 1, _stage["name"], int(_bpm)
	]

	# 특수 발판 효과 HUD (BPM 배수 + 회전 방향)
	_effect_lbl = _mk_label(ui, Vector2(24, 178), 16, Color(0.75, 0.90, 1.00))
	_update_effect_ui()

	_score_lbl     = _mk_label(ui, Vector2(24, 52), 30, Color.WHITE)
	_combo_lbl     = _mk_label(ui, Vector2(24, 92), 42, Color.YELLOW)
	_tile_info_lbl = _mk_label(ui, Vector2(24, 148), 18, Color(0.7, 0.7, 0.85))
	_acc_lbl       = _mk_label(ui, Vector2(24, 172), 18, Color(0.75, 0.90, 0.75))

	_judgment_lbl = Label.new()
	_judgment_lbl.add_theme_font_size_override("font_size", 60)
	_judgment_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judgment_lbl.size     = Vector2(vp.x, 110)
	_judgment_lbl.position = Vector2(0, vp.y * 0.14)
	ui.add_child(_judgment_lbl)

	# 과부하 게이지 (우상단)
	_ov_label_lbl = _mk_label(ui, Vector2(vp.x - OV_BAR_W - 24, 18), 14, Color(0.75, 0.75, 0.85))
	_ov_label_lbl.text = "OVERLOAD"

	_ov_bg = ColorRect.new()
	_ov_bg.size = Vector2(OV_BAR_W, OV_BAR_H)
	_ov_bg.position = Vector2(vp.x - OV_BAR_W - 24, 44)
	_ov_bg.color = Color(0.15, 0.15, 0.20, 0.55)
	_ov_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ov_bg)

	_ov_fill = ColorRect.new()
	_ov_fill.size = Vector2(0, OV_BAR_H)
	_ov_fill.position = _ov_bg.position
	_ov_fill.color = Color(1.0, 0.35, 0.35)
	_ov_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_ov_fill)

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

func _ready_and_go() -> void:
	_judgment_lbl.text     = "READY..."
	_judgment_lbl.modulate = Color(0.65, 0.80, 1.00)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree(): return
	_judgment_lbl.text     = "GO!"
	_judgment_lbl.modulate = Color(0.35, 1.00, 0.55)
	_trigger_flash(Color.WHITE, 0.12)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree(): return
	_judgment_lbl.text = ""
	_start_next_rotation()

# ══════════════════════════════════════════════════════════════════════
#  프레임 업데이트
# ══════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	_time += delta

	if _j_timer > 0.0:
		_j_timer -= delta
		if _j_timer <= 0.0 and not _cleared:
			_judgment_lbl.text = ""

	# 자동 미스 : Late! 상한(60°/40ms 중 큰 쪽) 넘으면 Late!! → 놓침...
	if running:
		var late_bound: float = _late_bound_seconds()
		if pair.elapsed > pair.beat_time + late_bound:
			_apply_judgment(J.LATE_2)

	# 과부하 게이지 자연 감쇠
	if overload_gauge > 0.0:
		overload_gauge = maxf(0.0, overload_gauge - _bpm * OVERLOAD_DRAIN_MULT * delta)
		_update_overload_ui()

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

		var impulse_rot: float = 0.0
		if _rot_time > 0.0:
			_rot_time = maxf(0.0, _rot_time - delta)
			var frac: float = _rot_time / CAM_IMPULSE_DUR
			impulse_rot = _rot_target * frac * frac
		var wobble: float = 0.0
		if _difficulty >= 5:
			wobble = sin(_time * 2.4) * 0.015
		cam.rotation = impulse_rot + wobble

		if _zoom_time > 0.0:
			_zoom_time = maxf(0.0, _zoom_time - delta)
			var zf: float = _zoom_time / CAM_IMPULSE_DUR
			var z: float = 1.0 + (_zoom_target - 1.0) * zf * zf
			cam.zoom = Vector2(z, z)
			if _zoom_time <= 0.0:
				cam.zoom = Vector2.ONE

	# 화면 플래시 (여린 흰색)
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 3.5)
		_flash_rect.color = Color(1.0, 1.0, 1.0, _flash_alpha)

# ══════════════════════════════════════════════════════════════════════
#  입력
# ══════════════════════════════════════════════════════════════════════
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
		if _bg_dots != null and running:
			_bg_dots.trigger_pulse(0.65)
		_try_hit()

# ══════════════════════════════════════════════════════════════════════
#  판정 : 각도-ms 이중 판정 (관대한 쪽 채택)
# ══════════════════════════════════════════════════════════════════════
func _angular_speed() -> float:
	# rad/sec. CW 회전으로 rotation_delta가 음수여도 절댓값으로 계산.
	if pair == null or pair.beat_time <= 0.001:
		return PI * _bpm * _bpm_mult / 60.0
	return absf(pair.rotation_delta) / pair.beat_time

func _to_deg(seconds: float) -> float:
	return seconds * _angular_speed() * 180.0 / PI

# Late! 판정 상한(초). 60° or 40ms 중 큰 쪽.
func _late_bound_seconds() -> float:
	var from_deg: float = deg_to_rad(T_LATE_DEG) / _angular_speed()
	return maxf(T_LATE_MS, from_deg)

func _judge(diff: float) -> int:
	var abs_d: float   = absf(diff)
	var abs_deg: float = _to_deg(abs_d)

	if abs_d <= T_PERFECT_MS or abs_deg <= T_PERFECT_DEG:
		return J.PERFECT
	if abs_d <= T_LPERFECT_MS or abs_deg <= T_LPERFECT_DEG:
		return J.E_PERFECT if diff < 0 else J.L_PERFECT
	if abs_d <= T_LATE_MS or abs_deg <= T_LATE_DEG:
		return J.EARLY if diff < 0 else J.LATE
	return J.EARLY_2 if diff < 0 else J.LATE_2

func _try_hit() -> void:
	if not running:
		return
	var diff: float = pair.elapsed - pair.beat_time
	# 극단적 조기 입력(연타 오작동) 방어 : -0.5s 이하 무시
	if diff < -0.5:
		return
	_apply_judgment(_judge(diff))

# ══════════════════════════════════════════════════════════════════════
#  판정 적용 / 각 판정별 처리
# ══════════════════════════════════════════════════════════════════════
func _apply_judgment(j: int) -> void:
	match j:
		J.PERFECT:
			_register_landed("Perfect!", 300, COL_PERFECT, true)
			perfect_count += 1
		J.E_PERFECT:
			_register_landed("EPerfect!", 250, COL_E_PERFECT, false)
			e_perfect_count += 1
		J.L_PERFECT:
			_register_landed("LPerfect!", 250, COL_L_PERFECT, false)
			l_perfect_count += 1
		J.EARLY:
			_register_landed("Early!", 150, COL_EARLY, false)
			early_count += 1
		J.LATE:
			_register_landed("Late!", 150, COL_LATE, false)
			late_count += 1
		J.EARLY_2:
			_register_early2()
		J.LATE_2:
			_register_miss()  # 실패 방지 ON 상수 → 놓침... 표시

# ── 착지 성공 (정확 ~ 느림!) ──
func _register_landed(text: String, pts: int, color: Color, is_perfect: bool) -> void:
	score += pts
	if is_perfect:
		combo += 1
	else:
		combo = 0
	max_combo = maxi(max_combo, combo)
	pair.trigger_landing_pulse()
	_show_judgment(text, color)

	var flash_a: float = 0.10 if is_perfect else 0.05
	_trigger_flash(Color.WHITE, flash_a * _diff_mult)
	_landing_cam_impulse(1.0 if is_perfect else 0.6)
	if _bg_dots != null:
		_bg_dots.trigger_pulse(1.0 if is_perfect else 0.75)

	_update_ui()
	_advance()

# ── 빠름!! : 착지 실패, 회전 유지, 과부하 게이지 채움 ──
func _register_early2() -> void:
	combo = 0
	early2_count += 1
	_show_judgment("Early!!", COL_EARLY_2)
	_trigger_flash(Color.WHITE, 0.08 * _diff_mult)
	_shake_intensity = 4.0 * _diff_mult
	_shake_time      = 0.18
	_add_overload(OVERLOAD_ADD_E2)
	_update_ui()
	# 주의 : _advance() 호출 없음. 회전은 계속 이어짐.

# ── Late!! → 실패 방지 ON 시 놓침... 처리 ──
func _register_miss() -> void:
	combo = 0
	miss_count += 1
	var text: String = "Miss..." if FAILURE_PREVENTION else "Late!!"
	var col: Color   = COL_MISS   if FAILURE_PREVENTION else COL_LATE_2
	_show_judgment(text, col)
	_trigger_flash(Color.WHITE, 0.10 * _diff_mult)
	_shake_intensity = 6.0 * _diff_mult
	_shake_time      = 0.28
	if _difficulty >= 2:
		_rot_target = randf_range(-1, 1) * 0.055 * _diff_mult
		_rot_time   = CAM_IMPULSE_DUR
	_add_overload(OVERLOAD_ADD_MISS)
	_update_ui()
	_advance()

# ── 과부하 게이지 관리 ──
func _add_overload(amount: float) -> void:
	overload_gauge += amount
	_update_overload_ui()
	if overload_gauge >= OVERLOAD_MAX:
		_trigger_overload()

func _trigger_overload() -> void:
	overload_gauge = 0.0
	overload_count += 1
	_show_judgment("Overload...", COL_OVERLOAD)
	_trigger_flash(Color.WHITE, 0.22 * _diff_mult)
	_shake_intensity = 10.0 * _diff_mult
	_shake_time      = 0.40
	_rot_target = randf_range(-1, 1) * 0.08 * _diff_mult
	_rot_time   = CAM_IMPULSE_DUR * 1.2
	_update_overload_ui()
	# 실패 방지 ON : 게이지 리셋 후 진행 지속. 게임오버 없음.

# ══════════════════════════════════════════════════════════════════════
#  카메라 임펄스 (난이도별)
# ══════════════════════════════════════════════════════════════════════
func _landing_cam_impulse(strength: float) -> void:
	if _difficulty <= 1:
		return
	_shake_intensity = 2.2 * float(_difficulty - 1) * strength
	_shake_time      = 0.12
	if _difficulty >= 3:
		var mag: float = 0.032 * float(_difficulty - 2) * strength
		_rot_target = randf_range(-1, 1) * mag
		_rot_time   = CAM_IMPULSE_DUR
	if _difficulty >= 4:
		_zoom_target = 1.0 + 0.025 * float(_difficulty - 3) * strength
		_zoom_time   = CAM_IMPULSE_DUR

# ══════════════════════════════════════════════════════════════════════
#  진행 / 다음 회전
# ══════════════════════════════════════════════════════════════════════
func _advance() -> void:
	pivot_idx += 1
	pair.swap_roles()

	# 새 피벗(방금 착지한 타일)의 특수 발판 효과 적용
	_apply_tile_effect(pivot_idx)

	if pivot_idx >= track.tiles.size() - 1:
		_game_clear()
		return
	_start_next_rotation()

# ── 특수 발판 효과 적용 ──
func _apply_tile_effect(idx: int) -> void:
	if track == null:
		return
	var t: int = track.type_at(idx)
	match t:
		Track.T_SPEED_UP:
			_bpm_mult *= 1.5
			_beat_time = 60.0 / (_bpm * _bpm_mult)
			_trigger_flash(Color.WHITE, 0.12)
			_show_judgment("SPEED UP", Track.COL_SPEED_UP)
		Track.T_SPEED_DOWN:
			_bpm_mult /= 1.5
			_beat_time = 60.0 / (_bpm * _bpm_mult)
			_trigger_flash(Color.WHITE, 0.12)
			_show_judgment("SLOW", Track.COL_SPEED_DOWN)
		Track.T_TWIRL:
			_rot_dir *= -1
			_trigger_flash(Color.WHITE, 0.14)
			_show_judgment("TWIRL", Track.COL_TWIRL)
		_:
			return
	_update_effect_ui()

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
	if _rot_dir > 0:
		while delta <= 0.001:
			delta += TAU
	else:
		while delta >= -0.001:
			delta -= TAU

	var duration: float = (absf(delta) / PI) * _beat_time

	pair.start_rotation(pivot_pos, start_angle, end_angle, duration, _rot_dir)
	running = true
	_update_ui()

# ══════════════════════════════════════════════════════════════════════
#  클리어
# ══════════════════════════════════════════════════════════════════════
func _game_clear() -> void:
	running = false
	_cleared = true
	pair.stop()

	track.set_current(track.tiles.size() - 1)

	var end_pos: Vector2 = track.tiles[track.tiles.size() - 1]
	var gold_count: int  = int(120.0 * _diff_mult)
	var white_count: int = int(40.0 * _diff_mult)
	_spawn_explosion(end_pos, Color(1.00, 0.85, 0.30), gold_count)
	_spawn_explosion(end_pos, Color(1.0, 1.0, 1.0), white_count)
	if _difficulty >= 3:
		_spawn_explosion(end_pos, Color(1.0, 0.4, 0.9), int(50 * _diff_mult))
	if _difficulty >= 4:
		_spawn_explosion(end_pos, Color(0.4, 0.9, 1.0), int(50 * _diff_mult))
	_shake_intensity = 12.0 * _diff_mult
	_shake_time      = 0.5 + _diff_mult * 0.1
	_rot_target = randf_range(-1, 1) * 0.08 * _diff_mult
	_rot_time   = CAM_IMPULSE_DUR * 1.4
	_trigger_flash(Color.WHITE, 0.28 * _diff_mult)
	if _bg_dots != null:
		_bg_dots.trigger_pulse(1.0)

	var pure: bool = _is_pure_perfect()
	var title: String = "★  PURE PERFECT!  ★" if pure else "★  CLEAR  ★"

	# 결과 화면 : 흰색 + 그림자로 뚜렷하게
	var vp: Vector2 = get_viewport_rect().size
	_judgment_lbl.size     = Vector2(vp.x, vp.y * 0.75)
	_judgment_lbl.position = Vector2(0, vp.y * 0.12)

	var settings := LabelSettings.new()
	settings.font_size      = 26
	settings.font_color     = Color.WHITE
	settings.shadow_size    = 6
	settings.shadow_color   = Color(0, 0, 0, 0.85)
	settings.shadow_offset  = Vector2(3, 3)
	settings.outline_size   = 2
	settings.outline_color  = Color(0, 0, 0, 0.65)
	_judgment_lbl.label_settings = settings
	_judgment_lbl.modulate = Color.WHITE

	_judgment_lbl.text = "%s\n\nSCORE  %d    MAX COMBO  %d    ACC  %.2f%%\n\n정확 %d   빠름 %d   느림 %d\n빠름! %d   느림! %d   빠름!! %d\n놓침 %d   과부하 %d\n\nENTER / SPACE 로 메뉴" % [
		title, score, max_combo, _get_accuracy(),
		perfect_count, e_perfect_count, l_perfect_count,
		early_count, late_count, early2_count,
		miss_count, overload_count
	]
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
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(p.queue_free)

# ══════════════════════════════════════════════════════════════════════
#  UI 헬퍼
# ══════════════════════════════════════════════════════════════════════
func _trigger_flash(_color: Color, alpha: float) -> void:
	_flash_alpha = maxf(_flash_alpha, alpha)

func _show_judgment(text: String, color: Color) -> void:
	if _cleared:
		return
	if _popup != null and pair != null:
		_popup.show_judgment(text, color, pair.pivot_pos)

func _get_accuracy() -> float:
	var total: int = maxi(pivot_idx, 1)
	var landed_perfect: int = perfect_count + e_perfect_count + l_perfect_count
	return float(perfect_count) * 0.01 + float(landed_perfect) * 100.0 / float(total)

func _is_pure_perfect() -> bool:
	# 모든 진행된 타일이 정확 판정이어야 함
	return perfect_count > 0 and perfect_count == pivot_idx and \
		e_perfect_count == 0 and l_perfect_count == 0 and \
		early_count == 0 and late_count == 0 and \
		early2_count == 0 and miss_count == 0 and overload_count == 0

func _update_overload_ui() -> void:
	if _ov_fill == null:
		return
	var pct: float = clampf(overload_gauge / OVERLOAD_MAX, 0.0, 1.0)
	_ov_fill.size = Vector2(OV_BAR_W * pct, OV_BAR_H)
	# 색상 : 낮음(초록) → 중간(주황) → 높음(빨강)
	if pct < 0.5:
		var t: float = pct / 0.5
		_ov_fill.color = Color(1.0, 0.55 + t * 0.15, 0.35 - t * 0.15)
	else:
		var t: float = (pct - 0.5) / 0.5
		_ov_fill.color = Color(1.0, 0.70 - t * 0.55, 0.20)

func _update_ui() -> void:
	_score_lbl.text = "SCORE  %d" % score
	_combo_lbl.text = "%d COMBO" % combo if combo >= 2 else ""
	if track != null:
		_tile_info_lbl.text = "TILE  %d / %d" % [pivot_idx + 1, track.tiles.size()]
	_acc_lbl.text = "ACC   %.2f%%" % _get_accuracy() if pivot_idx > 0 else "ACC   ---"

func _update_effect_ui() -> void:
	if _effect_lbl == null:
		return
	var eff_bpm: float = _bpm * _bpm_mult
	var dir_str: String = "CCW ↺" if _rot_dir > 0 else "CW ↻"
	_effect_lbl.text = "×%.2f  BPM %d   |   %s" % [_bpm_mult, int(eff_bpm), dir_str]
