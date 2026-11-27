class_name SledThumb
extends SubViewportContainer
## Miniatura 3D della muta (motori che corrono, navetta che sobbalza) per il menu.

var model: TeamModel
var _vp: SubViewport
var _cam: Camera3D

func _init(team: Color, w := 220, h := 62, seat := -1) -> void:
	stretch = true
	custom_minimum_size = Vector2(w, h)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.size = Vector2i(w * 2, h * 2)
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.88, 0.95)
	e.ambient_light_energy = 0.75
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.9
	_vp.add_child(sun)
	model = TeamModel.new()
	_vp.add_child(model)
	model.build(team, seat)
	model.run = 1.0
	model.rotation.y = deg_to_rad(-90)   # di profilo, verso destra
	_cam = Camera3D.new()
	var at := Vector3(0.1, 0.11, 0.0)
	var from := Vector3(0.1, 0.45, 1.45)
	_cam.transform = Transform3D(Basis.looking_at(at - from), from)   # fuori dall'albero: niente look_at
	_vp.add_child(_cam)
	resized.connect(_fit)
	_fit()

## Inquadra tutta la muta qualunque sia la forma del riquadro (stretto su iPad in verticale).
const FIT_W := 0.85    # larghezza della muta (navetta + motori) con un po' di margine
const FIT_H := 0.40    # altezza, conducente compreso
var fit_mul := 1.0      # > 1: più margine attorno (anteprima che ruota)
func _fit() -> void:
	var asp: float = max(size.x, 1.0) / max(size.y, 1.0) if size.y > 0 else custom_minimum_size.x / custom_minimum_size.y
	var h: float = max(FIT_H, FIT_W / asp) * fit_mul
	var d := 1.49
	_cam.fov = rad_to_deg(2.0 * atan(h * 0.5 / d))

## Rotazione lenta (officina): radianti al secondo, 0 = ferma di profilo.
var spin := 0.0
func _process(delta: float) -> void:
	if spin != 0.0 and model:
		model.rotation.y += spin * delta
	if fit_mul != _fit_done:
		_fit_done = fit_mul
		_fit()
var _fit_done := 1.0

## Fuori gara: ferma e sbiadita.
func set_active(on: bool) -> void:
	model.run = 1.0 if on else 0.0
	modulate = Color(1, 1, 1, 1.0 if on else 0.35)
