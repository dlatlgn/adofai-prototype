class_name JudgmentPopup
extends Node2D

# ── 판정 팝업 : 필기체 소형 텍스트가 공 뒤에서 위로 부드럽게 떠오르며 페이드 ──
#   Main에서 PlanetPair보다 먼저 add_child → Z-order 상 공 아래에 렌더

const LIFE: float = 1.0     # 표시 지속 시간(초)
const RISE: float = 34.0    # 총 상승 픽셀

var _label: Label
var _settings: LabelSettings
var _base_pos: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _active: bool = false
var _color: Color = Color.WHITE

func _ready() -> void:
	# 필기체 시스템 폰트 (Windows/macOS 대표 필기체 순차 폴백)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Segoe Script",
		"Brush Script MT",
		"Lucida Handwriting",
		"Monotype Corsiva",
		"Zapfino",
		"Comic Sans MS"
	])
	sf.font_italic = true

	_settings = LabelSettings.new()
	_settings.font        = sf
	_settings.font_size   = 26
	_settings.font_color  = Color.WHITE
	_settings.shadow_size = 3
	_settings.shadow_color  = Color(0, 0, 0, 0.75)
	_settings.shadow_offset = Vector2(2, 2)

	_label = Label.new()
	_label.label_settings          = _settings
	_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	_label.size                    = Vector2(200, 40)
	_label.position                = Vector2(-100, -20)
	_label.mouse_filter            = Control.MOUSE_FILTER_IGNORE
	_label.visible                 = false
	add_child(_label)

func show_judgment(text: String, color: Color, world_pos: Vector2) -> void:
	_label.text  = text
	_color       = color
	_settings.font_color = color
	_base_pos    = world_pos
	position     = world_pos
	_label.modulate = Color(1, 1, 1, 1)
	_label.visible = true
	_age = 0.0
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var t: float = _age / LIFE
	position.y  = _base_pos.y - RISE * t
	var alpha: float = clampf(1.0 - t, 0.0, 1.0)
	_label.modulate = Color(1, 1, 1, alpha)
	if _age >= LIFE:
		_active = false
		_label.visible = false
