extends Node2D

const PAGE_SIZE: int = 5

var selected: int = 0
var page: int = 0

var _stage_labels: Array[Label] = []
var _desc_label: Label
var _diff_label: Label
var _page_label: Label

const COL_SEL: Color   = Color(1.00, 0.87, 0.30)
const COL_IDLE: Color  = Color(0.55, 0.58, 0.72)
const COL_DIM: Color   = Color(0.55, 0.58, 0.72, 0.60)

func _total_pages() -> int:
	return (StageData.stages.size() + PAGE_SIZE - 1) / PAGE_SIZE

func _page_start() -> int:
	return page * PAGE_SIZE

func _page_end() -> int:
	return mini(_page_start() + PAGE_SIZE, StageData.stages.size())

func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size
	selected = StageData.current_index
	page = selected / PAGE_SIZE

	# ── 배경 ──
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09)
	bg.size = vp
	add_child(bg)

	# ── 상단 배너 ──
	var banner := ColorRect.new()
	banner.color = Color(0.08, 0.09, 0.16)
	banner.size = Vector2(vp.x, 190)
	banner.position = Vector2.ZERO
	add_child(banner)

	var title := Label.new()
	title.text = "얼불춤"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 90)
	title.position = Vector2(0, 40)
	title.modulate = Color(1.00, 0.87, 0.30)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A DANCE OF FIRE AND ICE"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(vp.x, 30)
	subtitle.position = Vector2(0, 128)
	subtitle.modulate = Color(0.55, 0.58, 0.72)
	add_child(subtitle)

	# ── 페이지 인디케이터 ──
	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 20)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size = Vector2(vp.x, 26)
	_page_label.position = Vector2(0, 206)
	_page_label.modulate = Color(0.85, 0.88, 1.00)
	add_child(_page_label)

	# ── 스테이지 리스트 (페이지당 PAGE_SIZE 행) ──
	var list_top: float = 244.0
	var row_h: float    = 44.0
	for i in PAGE_SIZE:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(vp.x, row_h)
		lbl.position = Vector2(0, list_top + i * row_h)
		add_child(lbl)
		_stage_labels.append(lbl)

	# ── 하단: 난이도 · 설명 ──
	var bottom_y: float = list_top + PAGE_SIZE * row_h + 18.0

	_diff_label = Label.new()
	_diff_label.add_theme_font_size_override("font_size", 20)
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_label.size = Vector2(vp.x, 28)
	_diff_label.position = Vector2(0, bottom_y)
	_diff_label.modulate = Color(1.00, 0.55, 0.35)
	add_child(_diff_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 18)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.size = Vector2(vp.x, 30)
	_desc_label.position = Vector2(0, bottom_y + 32)
	_desc_label.modulate = Color(0.75, 0.78, 0.90)
	add_child(_desc_label)

	var instr := Label.new()
	instr.text = "↑ ↓ 선택   |   ← → 페이지   |   ENTER 시작"
	instr.add_theme_font_size_override("font_size", 18)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.size = Vector2(vp.x, 30)
	instr.position = Vector2(0, vp.y - 46)
	instr.modulate = Color(0.45, 0.45, 0.55)
	add_child(instr)

	_refresh()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event
	if not ke.pressed or ke.echo:
		return

	if ke.keycode == KEY_UP or ke.keycode == KEY_W:
		_prev_item()
	elif ke.keycode == KEY_DOWN or ke.keycode == KEY_S:
		_next_item()
	elif ke.keycode == KEY_LEFT or ke.keycode == KEY_A:
		_prev_page()
	elif ke.keycode == KEY_RIGHT or ke.keycode == KEY_D:
		_next_page()
	elif ke.keycode == KEY_ENTER or ke.keycode == KEY_SPACE or ke.keycode == KEY_KP_ENTER:
		_start_stage()

func _prev_item() -> void:
	if selected > 0:
		selected -= 1
		page = selected / PAGE_SIZE
		_refresh()

func _next_item() -> void:
	if selected < StageData.stages.size() - 1:
		selected += 1
		page = selected / PAGE_SIZE
		_refresh()

func _prev_page() -> void:
	if page > 0:
		page -= 1
		selected = _page_start()
		_refresh()

func _next_page() -> void:
	if page < _total_pages() - 1:
		page += 1
		selected = _page_start()
		_refresh()

func _refresh() -> void:
	# 페이지 라벨
	var total: int = _total_pages()
	var left: String  = "◀  " if page > 0 else "     "
	var right: String = "  ▶" if page < total - 1 else "     "
	_page_label.text = "%s Page %d / %d %s" % [left, page + 1, total, right]

	# 스테이지 라벨
	var start: int = _page_start()
	for i in PAGE_SIZE:
		var idx: int = start + i
		if idx < StageData.stages.size():
			var s: Dictionary = StageData.stages[idx]
			var prefix: String = "▶  " if idx == selected else "    "
			_stage_labels[i].text = "%s%2d.  %-14s   BPM %d" % [
				prefix, idx + 1, s["name"], int(s["bpm"])
			]
			_stage_labels[i].modulate = COL_SEL if idx == selected else COL_IDLE
			_stage_labels[i].visible = true
		else:
			_stage_labels[i].visible = false

	# 하단 : 선택된 스테이지 정보
	var cur: Dictionary = StageData.stages[selected]
	var diff: int = int(cur["difficulty"])
	_diff_label.text = "난이도  " + "★".repeat(diff) + "☆".repeat(5 - diff)
	_desc_label.text = cur["desc"]

func _start_stage() -> void:
	StageData.current_index = selected
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
