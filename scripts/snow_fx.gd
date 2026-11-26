class_name SnowFx
extends RefCounted
## Decorazioni dell'interfaccia di Ion Tails: polvere del deserto che vola e una barra
## luminosa sul bordo superiore dei pannelli (il nome della classe viene da Snow Tails).

static var _flake: Texture2D = null

static func flake_texture() -> Texture2D:
	if _flake:
		return _flake
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.45, Color(1, 1, 1, 0.85))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_flake = t
	return t

## Nevicata leggera su tutta l'area (da aggiungere a un Control a tutto schermo).
static func snowfall(area: Vector2, amount := 140) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = flake_texture()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, area.y * 0.6)
	p.position = Vector2(-20, area.y * 0.5)
	p.direction = Vector2(1, 0.12)
	p.spread = 10.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.22
	p.color = Color(1.0, 0.72, 0.45, 0.55)
	# ondeggiare dei fiocchi
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	return p

## Cumulo di neve sul bordo superiore di un pannello largo w (disegnato in coordinate del pannello).
class SnowCap:
	extends Control
	var w := 400.0
	var seed_v := 7
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		# barra al neon con due tacche: niente neve su Ion Tails
		var c := Color("1fb3d1")
		draw_rect(Rect2(26, -3, w - 52, 4), Color(c, 0.35))
		draw_rect(Rect2(40, -2, w - 80, 2), c)
		draw_rect(Rect2(26, -6, 40, 3), Color("e0662a"))
		draw_rect(Rect2(w - 66, -6, 40, 3), Color("e0662a"))
