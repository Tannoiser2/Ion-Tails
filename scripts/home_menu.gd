class_name HomeMenu
extends Control
## Pagina iniziale a piena pagina: Gara, Editor, Officina, Regole.
## Su schermi larghi si vede l'immagine del gioco con i quattro pulsanti disegnati (sopra ci sono
## aree cliccabili); su schermi alti (telefono, iPad in verticale) l'immagine fa da sfondo e i
## pulsanti sono veri, grandi, uno sotto l'altro.

signal chosen(id: String)

const ART := "res://assets/ui/home.webp"
const COVER := "res://assets/ui/cover.webp"
const ART_SIZE := Vector2(1672, 941)
## Posizione dei pulsanti disegnati nell'immagine (pixel dell'immagine originale).
const SPOTS := {
	"race": Rect2(908, 274, 728, 126),
	"editor": Rect2(864, 416, 772, 126),
	"workshop": Rect2(836, 556, 800, 132),
	"rules": Rect2(848, 700, 788, 132),
}
const LABELS := {"race": "Gara", "editor": "Editor", "workshop": "Officina", "rules": "Regole"}
const COLORS := {
	"race": Color("e8601c"), "editor": Color("1f8fe8"), "workshop": Color("e8a81c"), "rules": Color("9a4fe0"),
}
const FILLS := {
	"race": Color("5e190e"), "editor": Color("0a2f6a"), "workshop": Color("4f2e0c"), "rules": Color("3e1c52"),
}

var can_resume := false
var can_fullscreen := false
var fullscreen_text := "Schermo intero"

var _back_art: TextureRect
var _back_cover: TextureRect
var _dim: ColorRect
var _art: TextureRect
var _spots_layer: Control
var _stack: Control
var _extras: HBoxContainer
var _keyart := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_back_art = _tex(ART, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_back_cover = _tex(COVER, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_art = _tex(ART, TextureRect.STRETCH_SCALE)
	_spots_layer = Control.new()
	_spots_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spots_layer)
	for id in SPOTS:
		_spots_layer.add_child(_hotspot(id))
	_build_stack()
	_extras = HBoxContainer.new()
	_extras.add_theme_constant_override("separation", 10)
	add_child(_extras)
	if can_resume:
		_extras.add_child(_small("Torna alla gara", "resume"))
	if can_fullscreen:
		_extras.add_child(_small(fullscreen_text, "fullscreen"))
	resized.connect(_layout)
	_layout()

func _tex(path: String, mode: int) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = mode
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	if mode != TextureRect.STRETCH_SCALE:
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return t

## Area cliccabile sopra un pulsante disegnato: trasparente, si accende al passaggio e al tocco.
func _hotspot(id: String) -> Button:
	var b := Button.new()
	b.name = "spot_" + id
	b.flat = false
	b.text = ""
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = LABELS[id]
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(1, 1, 1, 0)
	clear.set_corner_radius_all(22)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(1, 1, 1, 0.10)
	hov.border_color = Color(1, 1, 1, 0.85)
	hov.set_border_width_all(3)
	hov.set_corner_radius_all(22)
	hov.shadow_color = Color(COLORS[id], 0.7)
	hov.shadow_size = 14
	var prs := hov.duplicate() as StyleBoxFlat
	prs.bg_color = Color(1, 1, 1, 0.24)
	b.add_theme_stylebox_override("normal", clear)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("disabled", clear)
	b.pressed.connect(func(): chosen.emit(id))
	return b

func _build_stack() -> void:
	_stack = MarginContainer.new()
	_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		_stack.add_theme_constant_override("margin_" + s, 28)
	_stack.add_theme_constant_override("margin_bottom", 96)
	_stack.add_theme_constant_override("margin_top", 20)
	add_child(_stack)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_theme_constant_override("separation", 14)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(vb)
	for id in ["race", "editor", "workshop", "rules"]:
		var row := CenterContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_big_button(id))
		vb.add_child(row)

func _big_button(id: String) -> Button:
	var b := Button.new()
	b.name = "big_" + id
	b.text = String(LABELS[id]).to_upper()
	b.custom_minimum_size = Vector2(560, 104)
	b.add_theme_font_override("font", UIKit.font(UIKit.F_TITLE))
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color("fff1d6"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 6)
	var col: Color = COLORS[id]
	var mk := func(fill: Color, border: Color, bw: int) -> StyleBoxFlat:
		var st := StyleBoxFlat.new()
		st.bg_color = fill
		st.border_color = border
		st.set_border_width_all(bw)
		st.set_corner_radius_all(26)
		st.corner_radius_top_left = 8
		st.corner_radius_bottom_right = 8
		st.shadow_color = Color(col, 0.55)
		st.shadow_size = 12
		return st
	var base: Color = FILLS[id]
	b.add_theme_stylebox_override("normal", mk.call(Color(base, 0.92), col, 4))
	b.add_theme_stylebox_override("hover", mk.call(base.lightened(0.18), col.lightened(0.35), 5))
	b.add_theme_stylebox_override("pressed", mk.call(base.lightened(0.3), Color.WHITE, 5))
	b.add_theme_stylebox_override("focus", mk.call(base.lightened(0.18), Color.WHITE, 5))
	b.pressed.connect(func(): chosen.emit(id))
	return b

func _small(text: String, id: String) -> Button:
	var b := UIKit.button(text)
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = 0
	b.pressed.connect(func(): chosen.emit(id))
	return b

func _layout() -> void:
	var sz := size
	if sz.x < 8 or sz.y < 8:
		return
	_keyart = sz.x / sz.y >= 1.5
	_back_art.visible = _keyart
	_back_cover.visible = not _keyart
	_art.visible = _keyart
	_spots_layer.visible = _keyart
	_stack.visible = not _keyart
	_dim.color = Color(0.02, 0.03, 0.07, 0.62 if _keyart else 0.30)
	if _keyart:
		var sc: float = min(sz.x / ART_SIZE.x, sz.y / ART_SIZE.y)
		var isz := ART_SIZE * sc
		var org := ((sz - isz) * 0.5).floor()
		_art.position = org
		_art.size = isz
		for id in SPOTS:
			var r: Rect2 = SPOTS[id]
			var b: Control = _spots_layer.get_node("spot_" + id)
			b.position = org + r.position * sc
			b.size = r.size * sc
	else:
		var w: float = clamp(sz.x - 56.0, 280.0, 640.0)
		for id in SPOTS:
			var b: Button = _stack.find_child("big_" + id, true, false)
			b.custom_minimum_size = Vector2(w, clamp(sz.y * 0.1, 84.0, 120.0))
			b.add_theme_font_size_override("font_size", int(clamp(w / 15.0, 26.0, 40.0)))
	# in basso a sinistra le azioni secondarie
	_extras.position = Vector2(24, sz.y - 64)
