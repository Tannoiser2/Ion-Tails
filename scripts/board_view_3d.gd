class_name BoardView3D
extends Node3D
## Pista in 3D: tessere come tavole sul piano, mute low-poly, segnalini e telecamera orbitale.
## Usa le stesse coordinate del percorso (pixel delle tessere a 100 dpi): 100 px = 1 unità.

signal tapped(world_pos: Vector2)
signal follow_changed(on: bool)

const S := 0.01
var course: Course
var game: SledGame
var destinations: Array = []
var preview: Array = []      # anteprima dei percorsi: {path, from, end, dents, color}
var slot_markers: Array = []
var current_id := -1
var follow := true
var hud_top := 0.0
var hud_bottom := 0.0
var hud_right := 0.0
var replay := {}            # pid -> {pos: Vector3, dir: Vector2, run: float}
## Ion Tails: mine visibili a chi guarda, gadget del giro in vista (dopo la rivelazione)
var mine_cells: Array = []
var viewer_id := -1          # navetta di chi guarda (vede la propria anche se invisibile)
var shield_ids := {}         # navette con lo scudo già scoperto (si vede dalla partenza della mossa)
var _gates: Array = []       # [linea, materiale, numero olografico]
var show_al := false
var _nests: Array = []
var _nest_nodes: Array = []
var _smoke_nodes := {}

var cam: Camera3D
var target := Vector3.ZERO
var target_goal := Vector3.ZERO
var yaw := 0.0
var yaw_goal := 0.0
var pitch := deg_to_rad(42.0)
var dist := 3.6
var dist_goal := 3.6

var _env_built := false
var _tiles: Node3D
var _marks: Node3D
var _saps: Node3D
var _sap_nodes := {}        # casella -> masso
var _snow_nodes := {}       # casella -> cumulo di sabbia
var _snow_gone := {}        # cumuli già spazzati in questa animazione (prima che il gioco lo registri)
var _fx: Node3D
static var _puff_mat: StandardMaterial3D
var _teams := {}           # id -> {node: TeamModel, label: Label3D, ring: MeshInstance3D}
var _touches := {}
var _press := Vector2.ZERO
var _moved := false
var _pinch := 0.0
var _twist := 0.0
var _mid_y := 0.0
var _t := 0.0

## Tempo di ogni passo durante il movimento delle navette (secondi per casella).
const STEP_T := 0.35

## Percorso usato per la quota del terreno (salite e discese fanmade).
static var hcourse: Course = null

static func to3(v: Vector2, y := 0.0) -> Vector3:
	var h := 0.0
	if hcourse != null:
		h = hcourse.height_at(v)
	return Vector3(v.x * S, y + h, v.y * S)

func _build_env() -> void:
	if _env_built:
		return
	_env_built = true
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# cielo al tramonto di un pianeta desertico: viola in alto, arancio spento all'orizzonte
	sm.sky_top_color = Color("2a2450")
	sm.sky_horizon_color = Color("c9805a")
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color("a0603e")
	sm.ground_bottom_color = Color("5a3022")
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	env.tonemap_white = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color("8c5a4a")
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.72
	sun.light_color = Color("ffd9b8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	add_child(sun)
	# luce di riempimento fredda dal lato opposto: le pareti in ombra non diventano nere
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_energy = 0.22
	fill.light_color = Color("8fa8ff")
	add_child(fill)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 300.0
	add_child(cam)
	cam.make_current()

func setup(c: Course, g: SledGame) -> void:
	_build_env()
	course = c
	game = g
	if _tiles: _tiles.queue_free()
	if _marks: _marks.queue_free()
	if _saps: _saps.queue_free()
	for id in _teams:
		_teams[id]["node"].queue_free()
		_teams[id]["label"].queue_free()
		_teams[id]["ring"].queue_free()
	_teams.clear()
	BoardView3D.hcourse = c
	_slopes_cache = -1
	_tiles = Node3D.new()
	add_child(_tiles)
	_marks = Node3D.new()
	add_child(_marks)
	for i in c.pieces.size():
		# le tessere con il cartello del limite (curve, inversioni) stanno sopra le vicine,
		# così il cartello sul bordo d'ingresso non viene coperto dal rettilineo precedente
		var lift := 0.008 if int(c.pieces[i]["face"].get("limit", 0)) > 0 else 0.0
		var tm := _tile_mesh(c.pieces[i], 0.004 + 0.002 * (i % 3) + lift)
		_tiles.add_child(tm)
		var sh := MeshInstance3D.new()
		sh.mesh = tm.mesh
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = (tm.material_override as StandardMaterial3D).albedo_texture
		sm.albedo_color = Color(0.05, 0.08, 0.12, 0.45)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sh.material_override = sm
		# ombra della tessera, spostata e un po' più in basso; sui pendii più in basso ancora,
		# altrimenti lo spostamento la farebbe affiorare sopra la tessera
		var sloped: bool = float(c.pieces[i]["h0"]) != float(c.pieces[i]["h1"])
		sh.position = Vector3(0.06, -0.04 if sloped else -0.006, 0.08)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tiles.add_child(sh)
	SegmentFx.build(_tiles, c)
	_snow_nodes.clear()
	_snow_gone.clear()
	for n in _tiles.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("snow_cell"):
			_snow_nodes[int(n.get_meta("snow_cell"))] = n
	var ter := SegmentFx.terrain(c)
	_tiles.add_child(ter)
	_nests = ter.get_meta("nests", [])
	_build_limit_gates(c)
	_nest_nodes = ter.get_meta("nest_nodes", [])
	_smoke_nodes.clear()
	_saps = Node3D.new()
	add_child(_saps)
	if _fx == null:
		_fx = Node3D.new()
		add_child(_fx)
	for p in g.players:
		var tm := TeamModel.new()
		tm.build(p.color, p.seat)
		tm.visible = false
		add_child(tm)
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.font_size = 64
		lb.outline_size = 14
		lb.pixel_size = 0.0035
		lb.modulate = p.color.lightened(0.15)
		lb.outline_modulate = Color("1e3550")
		lb.no_depth_test = true
		lb.visible = false
		add_child(lb)
		var ring := _ring(0.4, p.color, 0.025)
		ring.visible = false
		add_child(ring)
		var blob := _disc(0.2, Color(0.08, 0.04, 0.02, 0.22))
		blob.scale = Vector3(1.15, 1.0, 2.7)
		tm.add_child(blob)
		blob.position = Vector3(0, 0.002, 0.02)
		_teams[p.id] = {"node": tm, "label": lb, "ring": ring, "placed": false}
	redraw()

func _tile_mesh(pc: Dictionary, y: float) -> MeshInstance3D:
	var tex := FaceDB.load_texture(pc["tex_path"])
	var img := tex.get_image() if tex else null
	if img:
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	var isc := float(pc["face"].get("img_scale", 1.0))
	var sz := (tex.get_size() / isc) if tex else Vector2(100, 100)
	var xf: Transform2D = pc["xf"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# griglia di quadratini: sulle salite e discese ogni vertice prende la quota del pendio
	var pi: int = course.pieces.find(pc) if course != null else -1
	var slope: bool = pi >= 0 and float(pc.get("h0", 0.0)) != float(pc.get("h1", 0.0))
	var flat_h: float = float(pc.get("h0", 0.0))
	var nx := 16 if slope else 1
	var ny := 16 if slope else 1
	for j in ny:
		for i in nx:
			var q := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var uv: Vector2 = q[idx] / Vector2(nx, ny)
				var p2: Vector2 = xf * (uv * sz)
				var hh: float = course.piece_height(pi, p2) if slope else flat_h
				st.set_normal(Vector3.UP)
				st.set_uv(uv)
				st.add_vertex(Vector3(p2.x * S, y + hh, p2.y * S))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.86, 0.84, 0.82)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _ring(r: float, col: Color, thick := 0.035) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r
	tm.rings = 40
	tm.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = TeamModel.mat(col, 1.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.3, 1)
	return mi

func _disc(r: float, col: Color) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.006
	cm.radial_segments = 32
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _bar(a: Vector3, b: Vector3, width: float, col: Color) -> MeshInstance3D:
	var d := b - a
	var L := Vector2(d.x, d.z).length()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.003, L + width * 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a + b) * 0.5
	mi.rotation.y = atan2(d.x, d.z)
	return mi

## Disegna una serie di percorsi come linee: passi in avanti sottili, passi di deriva
## (in diagonale) più spessi, più chiari e bordati di bianco.
func _draw_paths(paths: Array, from_cell: int, col: Color, y: float) -> void:
	var done := {}
	for path in paths:
		var prev: int = from_cell
		for id in path:
			var key := "%d>%d" % [prev, id]
			if not done.has(key):
				done[key] = true
				var a := to3(course.cells[prev]["pos"], y)
				var b := to3(course.cells[id]["pos"], y)
				var drift: bool = not (course.cells[prev]["fwd"] as Array).has(id)
				if drift:
					_marks.add_child(_bar(a, b, 0.095, Color(1, 1, 1, 0.95)))
					var c2 := col.lightened(0.35)
					c2.a = 0.95
					var bar := _bar(a, b, 0.06, c2)
					bar.position.y += 0.002
					_marks.add_child(bar)
				else:
					_marks.add_child(_bar(a, b, 0.035, Color(col, 0.85)))
			prev = id
	# puntini sulle caselle attraversate
	var dots := {}
	for path in paths:
		for id in path:
			dots[id] = true
	for id in dots:
		var d := _disc(0.045, Color(col.darkened(0.15), 0.95))
		d.position = to3(course.cells[id]["pos"], y + 0.004)
		_marks.add_child(d)

func _label(text: String, col: Color, size := 56) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = size
	lb.outline_size = 12
	lb.pixel_size = 0.0035
	lb.modulate = col
	lb.outline_modulate = Color.WHITE
	lb.no_depth_test = true
	return lb

static func _vertex_color_material(n: Node) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_vertex_color_material(c)

## Masso: alterna i modelli disponibili (sapling.glb, sapling_2.glb, …) per varietà.
## Masso sulla pista (al posto degli alberelli): roccia irregolare a facce piatte.
func _sapling_model(variant := 0) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + 5
	var m := TeamModel.mat(Color("6e4a3a").lerp(Color("8a6450"), rng.randf()), 0.95)
	for k in 3:
		var r := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(0.07, 0.11) * (1.0 if k == 0 else 0.7)
		sp.height = sp.radius * 2.0 * rng.randf_range(0.7, 1.1)
		sp.radial_segments = 6
		sp.rings = 3
		r.mesh = sp
		r.material_override = m
		r.position = Vector3(rng.randf_range(-0.06, 0.06) * k, sp.height * 0.4, rng.randf_range(-0.06, 0.06) * k)
		r.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
		n.add_child(r)
	var blob := _disc(0.14, Color(0.1, 0.05, 0.03, 0.35))
	blob.position = Vector3(0.03, 0.003, 0.04)
	n.add_child(blob)
	return n

## Ricostruisce segnalini, destinazioni, massi e scritte.
func redraw() -> void:
	if course == null or _marks == null:
		return
	# cumuli di sabbia: visibili finché nessuno ci è passato
	if game:
		for id in _snow_nodes:
			var sn: MeshInstance3D = _snow_nodes[id]
			var alive: bool = game.fresh.has(id) and not _snow_gone.has(id)
			if sn.has_meta("sweeping"):
				continue
			sn.visible = alive
			if alive:
				sn.transform = Transform3D.IDENTITY
	if _saps and game:
		for ch in _saps.get_children():
			ch.queue_free()
		_sap_nodes.clear()
		for id in game.saplings.keys():
			var sp := _sapling_model(int(id))
			sp.position = to3(course.cells[id]["pos"], 0.006)
			sp.rotation.y = float(id) * 1.7
			_saps.add_child(sp)
			_sap_nodes[int(id)] = sp
	for ch in _marks.get_children():
		ch.queue_free()
	var lw := course.lane_w * S
	for mc in mine_cells:
		var mn := _mine_model()
		mn.position = to3(course.cells[mc]["pos"], 0.01)
		_marks.add_child(mn)
	_sync_smoke()
	for sm in slot_markers:
		var p := to3(course.cells[sm["cell"]]["pos"], 0.012)
		var r := _ring(lw * 0.45, sm["color"])
		r.position = p
		_marks.add_child(r)
		var lb := _label(sm["text"], sm["color"].darkened(0.2))
		lb.position = p + Vector3(0, 0.12, 0)
		_marks.add_child(lb)
	for d in destinations:
		var col: Color = d["color"]
		var p := to3(course.cells[d["cell"]]["pos"], 0.012)
		var fill := col
		fill.a = 0.28
		var disc := _disc(lw * 0.44, fill)
		disc.position = p
		_marks.add_child(disc)
		var r := _ring(lw * 0.46, col, 0.045)
		r.position = p
		r.set_meta("pulse", true)
		_marks.add_child(r)
		if d["label"] != "":
			var lb := _label(d["label"], col)
			lb.position = p + Vector3(0, 0.2, 0)
			_marks.add_child(lb)
		var path: Array = d["path"]
		if path.size() > 0:
			_draw_paths([path], int(d.get("from", path[0])), col, 0.014)
	# anteprima dei percorsi possibili, nel colore della navetta
	if not preview.is_empty():
		var pcol: Color = preview[0]["color"]
		var paths := []
		for pv in preview:
			paths.append(pv["path"])
		_draw_paths(paths, int(preview[0]["from"]), pcol, 0.016)
		var ends := {}
		for pv in preview:
			if ends.has(pv["end"]):
				continue
			ends[pv["end"]] = true
			var endp := to3(course.cells[pv["end"]]["pos"], 0.014)
			var fill := pcol
			fill.a = 0.22
			var disc := _disc(lw * 0.36, fill)
			disc.position = endp
			_marks.add_child(disc)
			var r := _ring(lw * 0.38, pcol, 0.03)
			r.position = endp
			_marks.add_child(r)
			if int(pv["dents"]) > 0:
				var lb := _label(("bordo −%d" if String(pv.get("crash", "")) == "edge" else "−%d") % int(pv["dents"]), Color("d23a3a"), 44)
				lb.position = endp + Vector3(0, 0.16, 0)
				_marks.add_child(lb)
	_update_teams(true)

func _heading_of(cell_id: int) -> Vector2:
	return course.heading(cell_id)

static func yaw_of(h: Vector2) -> float:
	return atan2(h.x, -h.y)

func _update_teams(labels_only := false) -> void:
	if game == null:
		return
	var order := game.race_order()
	for p in game.players:
		var t: Dictionary = _teams[p.id]
		var node: TeamModel = t["node"]
		var lb: Label3D = t["label"]
		var ring: MeshInstance3D = t["ring"]
		if p.wrecked or p.cell < 0:
			node.visible = false
			lb.visible = false
			ring.visible = false
			continue
		var goal := to3(course.cells[p.cell]["pos"], 0.004)
		if not t["placed"]:
			node.position = goal
			node.rotation.y = -yaw_of(_heading_of(p.cell))
			t["placed"] = true
		node.visible = true
		var rk := order.find(p) + 1
		lb.text = str(rk) + (("  D%d" % p.dents) + ("½" if p.half else "") if p.dents > 0 else ("  D½" if p.half else ""))
		ring.visible = p.id == current_id
		# scudo: si vede da quando la navetta parte (e sempre sulla propria navetta)
		node.set_shield(p.al.has("sh") and (shield_ids.has(p.id) or p.id == viewer_id) and replay.is_empty())
		node.set_thrust(p.L, p.R)
		# invisibilità: sparisce per gli altri, chi la guida vede una sagoma trasparente
		var hid := 0
		if replay.is_empty() and game.invisible(p):
			hid = 2 if p.id == viewer_id else 1
		node.set_hidden(hid)
		lb.visible = hid != 1
		if hid == 1:
			ring.visible = false

# ---------- effetti: nuvole di neve, massi abbattuti, urti ----------
static func _puff_material() -> StandardMaterial3D:
	if _puff_mat:
		return _puff_mat
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	_puff_mat = m
	return m

## Nuvola di neve: una sbuffata morbida e qualche fiocco veloce.
func puff(pos: Vector3, power := 1.0) -> void:
	if _fx == null:
		return
	for layer in 2:
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * (0.36 if layer == 0 else 0.08) * power
		q.material = _puff_material()
		p.mesh = q
		p.one_shot = true
		p.explosiveness = 0.92
		p.amount = int((26 if layer == 0 else 34) * clamp(power, 0.6, 1.6))
		p.lifetime = 1.1 if layer == 0 else 0.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.09 * power
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = (0.25 if layer == 0 else 0.8) * power
		p.initial_velocity_max = (0.8 if layer == 0 else 1.8) * power
		p.gravity = Vector3(0, -0.6 if layer == 0 else -2.5, 0)
		p.damping_min = 1.2
		p.damping_max = 2.4
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.4
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(0.35, 1.0))
		sc.add_point(Vector2(1, 1.5 if layer == 0 else 0.6))
		p.scale_amount_curve = sc
		var cr := Gradient.new()
		# neve leggermente azzurrata e fiocchi più scuri: si vedono anche sulla pista bianca
		if layer == 0:
			cr.set_color(0, Color(0.78, 0.55, 0.38, 0.9))
			cr.set_color(1, Color(0.85, 0.66, 0.5, 0.0))
		else:
			cr.set_color(0, Color(0.5, 0.3, 0.2, 1.0))
			cr.set_color(1, Color(0.7, 0.48, 0.34, 0.0))
		p.color_ramp = cr
		p.position = pos
		_fx.add_child(p)
		p.emitting = true
		get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)

## L'masso viene travolto: cade nella direzione della navetta e sparisce nella neve.
func knock_sapling(cell_id: int, dir2: Vector2) -> void:
	if not _sap_nodes.has(cell_id):
		return
	var n: Node3D = _sap_nodes[cell_id]
	_sap_nodes.erase(cell_id)
	var pos := n.position
	n.get_parent().remove_child(n)
	_fx.add_child(n)
	n.position = pos
	var d3 := Vector3(dir2.x, 0, dir2.y).normalized()
	if d3.length() < 0.1:
		d3 = Vector3.FORWARD
	var axis := Vector3.UP.cross(d3).normalized()
	var base := n.basis
	var tw := create_tween()
	tw.tween_method(func(a: float): n.basis = Basis(axis, a) * base, 0.0, 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): puff(pos + d3 * 0.3 + Vector3(0, 0.04, 0), 0.8))
	tw.tween_interval(0.6)
	tw.tween_property(n, "scale", Vector3(0.001, 0.001, 0.001), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	puff(pos + Vector3(0, 0.08, 0), 0.7)

## Rimette tutti i cumuli secondo lo stato del gioco (inizio del replay).
func reset_snow() -> void:
	_snow_gone.clear()
	redraw()

## La navetta spazza via un cumulo di sabbia: si appiattisce e si apre a ventaglio,
## con una nuvola di neve sollevata nel senso di marcia.
func sweep_snow(cell_id: int, dir2: Vector2) -> void:
	if not _snow_nodes.has(cell_id):
		return
	var n: MeshInstance3D = _snow_nodes[cell_id]
	if not n.visible:
		return
	var c: Vector3 = n.get_meta("snow_center")
	var d3 := Vector3(dir2.x, 0, dir2.y).normalized()
	_snow_gone[cell_id] = true
	n.set_meta("sweeping", true)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		# schiacciato verso il basso, allargato e spinto avanti attorno al centro del cumulo
		var b := Basis().scaled(Vector3(1.0 + k * 0.5, 1.0 - k * 0.95, 1.0 + k * 0.5))
		n.transform = Transform3D(b, c - b * c + d3 * k * 0.25), 0.0, 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		n.visible = false
		n.remove_meta("sweeping"))
	for k in 3:
		puff(c + d3 * (0.15 + k * 0.18) + Vector3(0, 0.06, 0), 0.7 - k * 0.12)

## Urto contro il bordo o contro un'altra navetta: nuvola di neve e navette che sobbalzano.
func crash_fx(cell_id: int, hit_dir: Vector2, pid: int, other_pid := -1) -> void:
	var p0 := to3(course.cells[cell_id]["pos"], 0.0)
	var d3 := Vector3(hit_dir.x, 0, hit_dir.y).normalized()
	var at := p0 + d3 * (0.42 if other_pid < 0 else 0.5)
	puff(at + Vector3(0, 0.06, 0), 1.35)
	get_tree().create_timer(0.12).timeout.connect(func(): puff(at + d3 * 0.12 + Vector3(0, 0.1, 0), 0.9))
	if _teams.has(pid):
		(_teams[pid]["node"] as TeamModel).shake(1.0)
	if other_pid >= 0 and _teams.has(other_pid):
		(_teams[other_pid]["node"] as TeamModel).shake(0.7)

## Piccola sbandata (curva troppo veloce o salto troppo lento).
func skid_fx(cell_id: int, pid: int) -> void:
	puff(to3(course.cells[cell_id]["pos"], 0.05), 0.8)
	if _teams.has(pid):
		(_teams[pid]["node"] as TeamModel).shake(0.5)

func focus(world: Vector2, _smooth := true, force := false) -> void:
	if not follow and not force:
		return
	target_goal = to3(world)

func focus_cell(cell_id: int, force := false) -> void:
	if not follow and not force:
		return
	target_goal = to3(course.cells[cell_id]["pos"])
	if follow:
		yaw_goal = yaw_of(_heading_of(cell_id))

## Inquadra un insieme di punti della pista (coordinate del percorso).
func frame(points: Array, min_dist := 3.6, force := false) -> void:
	if points.is_empty() or (not follow and not force):
		return
	var mn: Vector2 = points[0]
	var mx: Vector2 = points[0]
	for p in points:
		mn = mn.min(p)
		mx = mx.max(p)
	target_goal = to3((mn + mx) * 0.5)
	var span := (mx - mn).length() * S
	dist_goal = clamp(span * 1.25 + 1.6, min_dist, 16.0)

var _track_dir := Vector2.ZERO

## Pendenza sotto la navetta (radianti, positiva in salita): serve per inclinare il modello.
func _slope_under(node: Node3D) -> float:
	if course == null or not _has_slopes():
		return 0.0
	var ry := node.rotation.y
	var f := Vector2(-sin(ry), -cos(ry)) * 0.3
	var p := Vector2(node.position.x, node.position.z)
	var h1 := course.height_at((p + f) / S)
	var h0 := course.height_at((p - f) / S)
	return atan2(h1 - h0, 0.6)

var _slopes_cache := -1
func _has_slopes() -> bool:
	if _slopes_cache < 0:
		_slopes_cache = 0
		for pc in course.pieces:
			if float(pc["h0"]) != float(pc["h1"]):
				_slopes_cache = 1
	return _slopes_cache == 1

## Obiettivo della telecamera mentre le navette si muovono: il centro del gruppo che corre,
## un po' avanti nel senso di marcia; distanza in base a quanto è sparpagliato il gruppo;
## rotazione verso la direzione media, filtrata per non ondeggiare a ogni curva.
func _track_moving(delta: float) -> void:
	var pts := []
	var dir_sum := Vector2.ZERO
	for pid in replay:
		var rp: Dictionary = replay[pid]
		if float(rp.get("run", 0.0)) > 0.3:
			pts.append(rp["pos"])
			dir_sum += rp["dir"]
	if pts.is_empty():
		for pid in replay:
			var q = game.players[pid] if pid < game.players.size() else null
			if q != null and not q.wrecked:
				pts.append(replay[pid]["pos"])
	if pts.is_empty():
		return
	var mn: Vector3 = pts[0]
	var mx: Vector3 = pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	if dir_sum.length() > 0.01:
		_track_dir = _track_dir.lerp(dir_sum.normalized(), 1.0 - exp(-2.0 * delta))
	var lead := Vector3(_track_dir.x, 0, _track_dir.y) * 0.35
	target_goal = (mn + mx) * 0.5 + lead
	var span := Vector2(mx.x - mn.x, mx.z - mn.z).length()
	dist_goal = clamp(span * 1.25 + 1.8, 3.2, 14.0)
	if _track_dir.length() > 0.2:
		yaw_goal = yaw_of(_track_dir.normalized())

func set_follow(on: bool) -> void:
	follow = on
	follow_changed.emit(on)

func _process(delta: float) -> void:
	_t += delta
	_animate_gates(delta)
	if cam == null:
		return
	var k := 1.0 - exp(-5.0 * delta)
	var kd := k
	var ky := 1.0 - exp(-3.0 * delta)
	if follow and not replay.is_empty() and game != null:
		# navette in movimento (replay o movimento simultaneo): la telecamera le segue con continuità
		_track_moving(delta)
		k = 1.0 - exp(-3.0 * delta)
		kd = 1.0 - exp(-1.6 * delta)
		ky = 1.0 - exp(-1.4 * delta)
	target = target.lerp(target_goal, k)
	yaw = lerp_angle(yaw, yaw_goal, ky)
	dist = lerp(dist, dist_goal, kd)
	var fwd := Vector3(sin(yaw), 0, -cos(yaw))
	cam.position = target - fwd * dist * cos(pitch) + Vector3.UP * dist * sin(pitch)
	cam.look_at(target, Vector3.UP)
	# sposta l'inquadratura nella parte di schermo lasciata libera dai pannelli
	var vs := get_viewport().get_visible_rect().size
	if vs.y > 0:
		var world_h := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5)
		cam.v_offset = -(hud_bottom - hud_top) * 0.5 / vs.y * world_h
		cam.h_offset = hud_right * 0.5 / vs.y * world_h
	# mute: avanzano verso la casella e si girano nel senso di marcia
	if game:
		for p in game.players:
			if not _teams.has(p.id) or p.wrecked or p.cell < 0:
				continue
			var t: Dictionary = _teams[p.id]
			var node: TeamModel = t["node"]
			if replay.has(p.id):
				var rp: Dictionary = replay[p.id]
				node.position = rp["pos"]
				node.rotation.y = lerp_angle(node.rotation.y, -yaw_of(rp["dir"]), 1.0 - exp(-14.0 * delta))
				node.run = move_toward(node.run, float(rp["run"]), delta * 5.0)
				node.slope = _slope_under(node)
				(t["label"] as Label3D).position = node.position + Vector3(0, 0.42, 0)
				(t["ring"] as MeshInstance3D).visible = false
				continue
			var goal := to3(course.cells[p.cell]["pos"], 0.004)
			var to_goal := goal - node.position
			var dd := to_goal.length()
			var moving := dd > 0.02
			if moving:
				# passo costante: una casella ogni STEP_T secondi (un po' di margine per le diagonali)
				node.position = node.position.move_toward(goal, delta * max(course.cell_len * S / STEP_T * 1.25, dd * 2.5))
				# guarda lungo la pista (non verso lo spostamento): di lato scivola, non si gira
				node.rotation.y = lerp_angle(node.rotation.y, -yaw_of(_heading_of(p.cell)), 1.0 - exp(-8.0 * delta))
			else:
				node.rotation.y = lerp_angle(node.rotation.y, -yaw_of(_heading_of(p.cell)), 1.0 - exp(-4.0 * delta))
			node.run = move_toward(node.run, 1.0 if moving else 0.0, delta * 4.0)
			node.slope = _slope_under(node)
			var lb: Label3D = t["label"]
			lb.position = node.position + Vector3(0, 0.42, 0)
			var ring: MeshInstance3D = t["ring"]
			ring.position = node.position + Vector3(0, 0.01, 0)
			var s := 1.0 + sin(_t * 4.0) * 0.06
			ring.scale = Vector3(s, 0.3, s)
	if _marks:
		var ps := 1.0 + sin(_t * 5.0) * 0.07
		for ch in _marks.get_children():
			if ch.has_meta("pulse"):
				ch.scale = Vector3(ps, 0.3, ps)

# ---------- input ----------
func _screen_to_world(pos: Vector2) -> Vector2:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	if abs(dir.y) < 0.0001:
		return Vector2(INF, INF)
	# La pista non è a quota zero (rilevato, salite, discese): si interseca il raggio
	# con il piano alla quota del terreno sotto il punto, raffinando qualche volta.
	var h := 0.0
	var p := Vector2.ZERO
	for _i in 4:
		var t := (h - from.y) / dir.y
		var hit := from + dir * t
		p = Vector2(hit.x / S, hit.z / S)
		if hcourse == null:
			break
		var nh := hcourse.height_at(p)
		if abs(nh - h) < 0.002:
			break
		h = nh
	return p

func _pan(rel: Vector2) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var scale_: float = 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / max(vh, 1.0)
	var right := Vector3(cos(yaw), 0, sin(yaw))
	var fwd := Vector3(sin(yaw), 0, -cos(yaw))
	target_goal += (-right * rel.x + fwd * rel.y / max(sin(pitch), 0.4)) * scale_
	target = target_goal
	if follow: set_follow(false)

func _unhandled_input(ev: InputEvent) -> void:
	if cam == null:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press = ev.position
				_moved = false
			elif _touches.size() == 2:
				var v: Array = _touches.values()
				_pinch = (v[0] as Vector2).distance_to(v[1])
				_twist = ((v[1] as Vector2) - (v[0] as Vector2)).angle()
				_mid_y = ((v[0] as Vector2).y + (v[1] as Vector2).y) * 0.5
		else:
			_touches.erase(ev.index)
			if _touches.is_empty() and not _moved:
				tapped.emit(_screen_to_world(ev.position))
	elif ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			if ev.position.distance_to(_press) > 12:
				_moved = true
			if _moved:
				_pan(ev.relative)
		elif _touches.size() == 2:
			_moved = true
			var v: Array = _touches.values()
			var a: Vector2 = v[0]
			var b: Vector2 = v[1]
			var d := a.distance_to(b)
			if _pinch > 0:
				dist_goal = clamp(dist_goal * _pinch / d, 1.5, 30.0)
				dist = dist_goal
				if follow and abs(_pinch / d - 1.0) > 0.01: set_follow(false)
			_pinch = d
			var ang := (b - a).angle()
			var da := wrapf(ang - _twist, -PI, PI)
			if abs(da) > 0.002:
				yaw_goal -= da
				yaw = yaw_goal
				if follow: set_follow(false)
			_twist = ang
			var my := (a.y + b.y) * 0.5
			pitch = clamp(pitch + (my - _mid_y) * 0.004, deg_to_rad(18), deg_to_rad(88))
			_mid_y = my
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist_goal = clamp(dist_goal / 1.12, 1.5, 30.0)
			if follow: set_follow(false)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist_goal = clamp(dist_goal * 1.12, 1.5, 30.0)
			if follow: set_follow(false)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		yaw_goal += ev.relative.x * 0.006
		yaw = yaw_goal
		pitch = clamp(pitch + ev.relative.y * 0.005, deg_to_rad(18), deg_to_rad(88))
		if follow: set_follow(false)


# ---------- Ion Tails: gadget sulla pista ----------
## Mina vista (propria o col radar): disco scuro con una luce rossa che pulsa.
func _mine_model() -> Node3D:
	var n := Node3D.new()
	var b := MeshInstance3D.new()
	b.mesh = TeamModel.cyl(0.075, 0.09, 0.035, 12)
	b.material_override = TeamModel.metal(Color("2d3138"), 0.5)
	b.position.y = 0.018
	n.add_child(b)
	for k in 4:
		var sp := MeshInstance3D.new()
		sp.mesh = TeamModel.cyl(0.006, 0.01, 0.04, 5)
		sp.material_override = TeamModel.metal(Color("7d858f"))
		sp.position = Vector3(cos(k * PI / 2) * 0.06, 0.04, sin(k * PI / 2) * 0.06)
		n.add_child(sp)
	var l := MeshInstance3D.new()
	l.mesh = TeamModel.sph(0.022)
	l.material_override = TeamModel.glow(Color("ff3b2f"), 1.4)
	l.position.y = 0.045
	l.set_meta("blink", true)
	n.add_child(l)
	var r := _ring(0.16, Color("ff3b2f"), 0.012)
	r.position.y = 0.004
	r.set_meta("pulse", true)
	n.add_child(r)
	return n

## Nubi di fumo sulle caselle (restano fino alla fine del giro).
func _sync_smoke() -> void:
	if game == null:
		return
	for id in _smoke_nodes.keys():
		if not game.smoke.has(id):
			(_smoke_nodes[id] as Node3D).queue_free()
			_smoke_nodes.erase(id)
	for id in game.smoke:
		if _smoke_nodes.has(id):
			continue
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.5
		q.material = _puff_material()
		p.mesh = q
		p.amount = 10
		p.lifetime = 3.0
		p.preprocess = 3.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.22
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 0.02
		p.initial_velocity_max = 0.08
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.5
		var cr := Gradient.new()
		cr.set_color(0, Color(0.55, 0.52, 0.6, 0.0))
		cr.add_point(0.3, Color(0.62, 0.6, 0.68, 0.75))
		cr.set_color(cr.get_point_count() - 1, Color(0.7, 0.68, 0.75, 0.0))
		p.color_ramp = cr
		p.position = to3(course.cells[id]["pos"], 0.15)
		_fx.add_child(p)
		_smoke_nodes[id] = p

## Nido più vicino a un punto (per i colpi dei cecchini).
func _nest_near(at: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in _nests.size():
		var d := (_nests[i] as Vector3).distance_squared_to(at)
		if d < bd:
			bd = d
			best = i
	return best

func ship_pos(pid: int) -> Vector3:
	if _teams.has(pid):
		return (_teams[pid]["node"] as Node3D).position + Vector3(0, 0.12, 0)
	return Vector3.ZERO

## Scritta che sale e svanisce sopra un punto: l'esito di un gadget a colpo d'occhio.
const C_HIT := Color("ff6a3a")
const C_BLOCK := Color("6fe3ff")
const C_MISS := Color("c9ccd4")
const C_GOOD := Color("ffd36b")
var _popups: Array = []      # [ms, posizione] delle scritte recenti
func popup(at: Vector3, text: String, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.font_size = 46
	lb.outline_size = 12
	# grandezza costante sullo schermo: cresce con la distanza della telecamera
	lb.pixel_size = clamp(0.0007 * dist, 0.0025, 0.012)
	lb.modulate = col
	lb.outline_modulate = Color(0.05, 0.04, 0.08, 0.95)
	var rise: float = clamp(0.07 * dist, 0.35, 1.0)
	# scritte vicine e quasi contemporanee: una sopra l'altra, senza sovrapporsi
	var now := Time.get_ticks_msec()
	var stack := 0
	for q in _popups:
		if now - int(q[0]) < 900 and (q[1] as Vector3).distance_to(at) < 0.25 * dist:
			stack += 1
	_popups.append([now, at])
	if _popups.size() > 30:
		_popups.pop_front()
	lb.position = at + Vector3(0, rise * (1.0 + 0.55 * stack), 0)
	_fx.add_child(lb)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", lb.position.y + rise, 1.6)
	tw.tween_property(lb, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.chain().tween_callback(lb.queue_free)

## Raggio laser del cecchino dal canyon verso la navetta.
## res: "hit" (piccola esplosione), "shield" (bolla dello scudo), "miss" (colpo a vuoto),
## "invisible" (il cecchino spara alla cieca), "decoy".
func laser_fx(pid: int, res: String) -> void:
	var to := ship_pos(pid)
	var ni := _nest_near(to)
	var from := to + Vector3(1.5, 1.2, 0.5)
	if ni >= 0:
		from = (_nests[ni] as Vector3) + Vector3(0, 0.1, 0)
		var nn: Node3D = _nest_nodes[ni] if ni < _nest_nodes.size() else null
		if nn:
			var d := to - nn.global_position
			nn.rotation.y = atan2(-d.x, -d.z)
	var end := to
	if res in ["miss", "invisible", "smoke", "decoy"]:
		end = to + Vector3(randf_range(-0.45, 0.45), -0.1, randf_range(-0.45, 0.45))
	elif res == "shield":
		end = to + (from - to).normalized() * 0.32
	var beam := MeshInstance3D.new()
	beam.mesh = TeamModel.cyl(0.014, 0.014, 1.0, 6)
	var bm := TeamModel.glow(Color("ff4a3a"), 2.0, 0.95)
	beam.material_override = bm
	var d3 := end - from
	var up := d3.normalized()
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	beam.basis = Basis(x, up, x.cross(up).normalized()) * Basis.from_scale(Vector3(1, d3.length(), 1))
	beam.position = (from + end) * 0.5
	_fx.add_child(beam)
	var tw := create_tween()
	tw.tween_property(bm, "albedo_color:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_callback(beam.queue_free)
	spark(from, Color("ff8a6a"), 0.4)
	match res:
		"hit":
			_blast_at(to, 0.55)
			if _teams.has(pid):
				(_teams[pid]["node"] as TeamModel).shake(0.9)
			popup(to, "COLPITA", C_HIT)
		"shield":
			flash_shield(pid)
			spark(end, C_BLOCK, 0.9)
			popup(to, "SCUDO", C_BLOCK)
		"invisible":
			puff(end, 0.5)
			popup(from, "BERSAGLIO INVISIBILE", C_MISS)
		"decoy":
			hologram(to)
		_:
			puff(end, 0.6)
			spark(end, Color("ffb066"), 0.5)
			popup(to, "MANCATA", C_MISS)

## Scintille e piccolo lampo.
func spark(at: Vector3, col: Color, power := 1.0) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.05 * power
	var m := _puff_material().duplicate() as StandardMaterial3D
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(30 * power)
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.6 * power
	p.initial_velocity_max = 1.6 * power
	p.gravity = Vector3(0, -2.0, 0)
	var cr := Gradient.new()
	cr.set_color(0, Color(col, 1.0))
	cr.set_color(1, Color(col, 0.0))
	p.color_ramp = cr
	p.position = at
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Esplosione di una mina: lampo, scintille e polvere.
func explosion_fx(cell_id: int) -> void:
	var at := to3(course.cells[cell_id]["pos"], 0.08)
	var fl := MeshInstance3D.new()
	fl.mesh = TeamModel.sph(0.25)
	var fm := TeamModel.glow(Color("ff9a3c"), 2.0, 0.85)
	fl.material_override = fm
	fl.position = at
	_fx.add_child(fl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fl, "scale", Vector3.ONE * 2.2, 0.35)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(fl.queue_free)
	spark(at, Color("ffcc66"), 1.6)
	puff(at, 1.5)
	popup(at, "MINA!", C_HIT)

## Il colpo si spegne sullo scudo: bolla traslucida attorno alla navetta per un secondo.
func flash_shield(pid: int) -> void:
	if not _teams.has(pid):
		return
	var node: TeamModel = _teams[pid]["node"]
	var b := MeshInstance3D.new()
	b.mesh = TeamModel.sph(0.5)
	var m := TeamModel.glow(Color("58d8ff"), 0.9, 0.32)
	b.material_override = m
	b.scale = Vector3(0.62, 0.36, 0.92) * 0.85
	b.position = Vector3(0, 0.16, 0)
	node.add_child(b)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "scale", Vector3(0.62, 0.36, 0.92) * 1.05, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6).set_delay(0.9)
	tw.chain().tween_callback(b.queue_free)
	spark(ship_pos(pid), Color("7fe8ff"), 0.8)

## Esca olografica: una sagoma trasparente che si dissolve.
func hologram(at: Vector3) -> void:
	var h := MeshInstance3D.new()
	h.mesh = TeamModel.box(0.3, 0.12, 0.7)
	var m := TeamModel.glow(Color("7fe8ff"), 1.0, 0.35)
	h.material_override = m
	h.position = at
	_fx.add_child(h)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(h.queue_free)

## Impulso EMP: anello azzurro che si allarga.
func emp_fx(cell_id: int) -> void:
	var at := to3(course.cells[cell_id]["pos"], 0.1)
	var r := _ring(0.3, Color("8af6ff"), 0.03)
	r.position = at
	_fx.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3.ONE * 6.0, 0.6)
	tw.tween_callback(r.queue_free)
	spark(at, Color("8af6ff"), 1.2)

## Arpione: cavo luminoso fra due navette per un attimo.
var _blast_wave := {}

func hook_fx(pid: int, to_pid: int, lv := 0, show_n := false) -> void:
	var a := ship_pos(pid)
	var b := ship_pos(to_pid)
	var beam := MeshInstance3D.new()
	beam.mesh = TeamModel.cyl(0.008, 0.008, 1.0, 6)
	var bm := TeamModel.glow(Color("ffd36b"), 1.4, 0.9)
	beam.material_override = bm
	var d3 := b - a
	if d3.length() < 0.01:
		return
	var up := d3.normalized()
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	beam.basis = Basis(x, up, x.cross(up).normalized()) * Basis.from_scale(Vector3(1, d3.length(), 1))
	beam.position = (a + b) * 0.5
	_fx.add_child(beam)
	var tw := create_tween()
	tw.tween_property(bm, "albedo_color:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(beam.queue_free)
	if show_n or lv > 0:
		popup(b, "ARPIONE: INDIETRO DI %d" % lv if lv > 0 else "ARPIONE: BLOCCATO", C_GOOD if lv > 0 else C_MISS)

## Postbruciatore: fiammata dai motori.
func boost_fx(pid: int, lv := 1) -> void:
	spark(ship_pos(pid), Color("7fe8ff"), 1.0)
	popup(ship_pos(pid), "POSTBRUCIATORE +%d" % lv, C_GOOD)

## Missile: un piccolo razzo luminoso che segue le caselle; alla fine esplode o si spegne.
func missile_fx(cells: Array, res: String, pid: int, defl: Array = []) -> void:
	if cells.size() < 2:
		return
	defl = defl.duplicate(true)    # i dati restano intatti per il replay
	var m := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = TeamModel.caps(0.025, 0.12)
	body.material_override = TeamModel.metal(Color("c8ced6"), 0.4)
	body.rotation.x = PI / 2
	m.add_child(body)
	var fl := MeshInstance3D.new()
	fl.mesh = TeamModel.cyl(0.0, 0.022, 0.1, 8)
	fl.material_override = TeamModel.glow(Color("ffb066"), 1.6, 0.8)
	fl.rotation.x = PI / 2
	fl.position.z = 0.1
	m.add_child(fl)
	_fx.add_child(m)
	var pts := []
	for c in cells:
		pts.append(to3(course.cells[int(c)]["pos"], 0.22))
	var t := 0.0
	var dur: float = 0.09 * float(pts.size() - 1) + 0.15
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var x: float = clamp(t / dur, 0.0, 1.0) * float(pts.size() - 1)
		var k: int = min(int(floor(x)), pts.size() - 2)
		while not defl.is_empty() and int(defl[0][0]) <= k:
			var dd: Array = defl.pop_front()
			spark(pts[int(dd[0])], Color("b48cff"), 1.0)
			popup(pts[int(dd[0])], "CME: DEVIATO", C_BLOCK)
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		m.position = a.lerp(b, x - k)
		var d := b - a
		if d.length() > 0.001:
			m.rotation.y = atan2(-d.x, -d.z)
		if randf() < 0.5:
			puff(m.position, 0.25)
	var end: Vector3 = pts[pts.size() - 1]
	m.queue_free()
	match res:
		"hit":
			_blast_at(end)
			if _teams.has(pid):
				(_teams[pid]["node"] as TeamModel).shake(1.0)
			popup(end, "MISSILE A SEGNO", C_HIT)
		"shield":
			flash_shield(pid)
			popup(end, "SCUDO", C_BLOCK)
		"boom":
			_blast_at(end, 0.7)
			popup(end, "CME: ESPLOSO", C_BLOCK)
		"wall":
			_blast_at(end, 0.7)
			popup(end, "MANCATO", C_MISS)
		_:
			puff(end, 0.6)
			popup(end, "MANCATO", C_MISS)

func _blast_at(at: Vector3, sz := 1.0) -> void:
	var fl := MeshInstance3D.new()
	fl.mesh = TeamModel.sph(0.2 * sz)
	var fm := TeamModel.glow(Color("ff9a3c"), 2.0, 0.85)
	fl.material_override = fm
	fl.position = at
	_fx.add_child(fl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fl, "scale", Vector3.ONE * 2.0, 0.3)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(fl.queue_free)
	spark(at, Color("ffcc66"), 1.3)

## Blast ionico: onda azzurra dalla navetta verso quella spinta di lato.
func blast_fx(pid: int, to_pid: int, crash := false, n := 1) -> void:
	# onda d'urto che parte dalla navetta (una sola per turno anche con più bersagli)
	var now := Time.get_ticks_msec()
	if int(_blast_wave.get(pid, -100000)) < now - 300:
		_blast_wave[pid] = now
		var at := ship_pos(pid)
		for i in 3:
			var r := _ring(0.3, Color("4fc8e8"), 0.012)
			var rm := TeamModel.glow(Color("4fc8e8"), 1.0, 0.75)
			r.material_override = rm
			r.position = at + Vector3(0, 0.05, 0)
			r.scale = Vector3(0.3, 0.08, 0.3)
			_fx.add_child(r)
			var tw := create_tween()
			tw.tween_interval(0.15 * i)
			tw.set_parallel(true)
			tw.tween_property(r, "scale", Vector3(4.5, 0.08, 4.5), 0.7).set_ease(Tween.EASE_OUT)
			tw.tween_property(rm, "albedo_color:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(r.queue_free)
		spark(at, Color("8af6ff"), 0.8)
		if to_pid < 0:
			popup(at, "BLAST IONICO: NESSUNO", C_MISS)
	if to_pid < 0:
		return
	emp_fx_at(ship_pos(to_pid))
	if _teams.has(to_pid):
		(_teams[to_pid]["node"] as TeamModel).shake(0.8)
	if crash:
		_blast_at(ship_pos(to_pid), 0.5)
		popup(ship_pos(to_pid), "BLAST: CONTRO IL BORDO", C_HIT)
	elif n > 0:
		popup(ship_pos(to_pid), "BLAST: SPINTA", C_GOOD)
	else:
		popup(ship_pos(to_pid), "BLAST: BLOCCATA", C_MISS)

func emp_fx_at(at: Vector3) -> void:
	var r := _ring(0.25, Color("8af6ff"), 0.03)
	r.position = at
	_fx.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3.ONE * 3.0, 0.45)
	tw.tween_callback(r.queue_free)


# ---------- limiti delle curve: barriera elettrificata con il numero olografico ----------
func _build_limit_gates(c: Course) -> void:
	_gates.clear()
	for l in c.limits:
		var a: Vector3 = to3(l["a"], 0.0)
		var b: Vector3 = to3(l["b"], 0.0)
		var ext := (b - a).normalized() * 0.25
		a -= ext
		b += ext
		var g := Node3D.new()
		_tiles.add_child(g)
		# due piloni alle estremità
		for p in [a, b]:
			var py := MeshInstance3D.new()
			py.mesh = TeamModel.cyl(0.035, 0.055, 0.7, 8)
			py.material_override = TeamModel.metal(Color("4a525e"), 0.5)
			py.position = p + Vector3(0, 0.35, 0)
			g.add_child(py)
			var tip := MeshInstance3D.new()
			tip.mesh = TeamModel.sph(0.05)
			tip.material_override = TeamModel.glow(Color("8af6ff"), 2.0)
			tip.position = p + Vector3(0, 0.72, 0)
			g.add_child(tip)
		# linea elettrificata (due fili che sfarfallano) all'altezza delle punte
		var mats := []
		for k in 2:
			var w := MeshInstance3D.new()
			var d := b - a
			w.mesh = TeamModel.cyl(0.016, 0.016, 1.0, 6)
			var m := TeamModel.glow(Color("3fd0ff"), 1.3, 0.8)
			w.material_override = m
			var up := d.normalized()
			var x := up.cross(Vector3.UP).normalized()
			w.basis = Basis(x, up, x.cross(up).normalized()) * Basis.from_scale(Vector3(1, d.length(), 1))
			w.position = (a + b) * 0.5 + Vector3(0, 0.72 - k * 0.1, 0)
			g.add_child(w)
			mats.append(m)
		# numero olografico a mezz'aria che ruota
		var holo := Node3D.new()
		holo.position = (a + b) * 0.5 + Vector3(0, 1.35, 0)
		g.add_child(holo)
		for side in [0.0, PI]:
			var lb := Label3D.new()
			lb.text = str(l["lim"])
			lb.font = load(UIKit.F_TITLE)
			lb.font_size = 220
			lb.pixel_size = 0.004
			lb.outline_size = 18
			lb.modulate = Color(0.6, 0.97, 1.0, 0.9)
			lb.outline_modulate = Color(0.05, 0.45, 0.95, 0.75)
			lb.shaded = false
			lb.double_sided = false
			lb.rotation.y = side
			holo.add_child(lb)
		var ring := _ring(0.38, Color("8af6ff"), 0.018)
		ring.position = holo.position - Vector3(0, 0.55, 0)
		g.add_child(ring)
		_gates.append([mats, holo, randf() * TAU])

func _animate_gates(delta: float) -> void:
	for gt in _gates:
		var holo: Node3D = gt[1]
		if not is_instance_valid(holo):
			continue
		holo.rotation.y += delta * 1.2
		holo.position.y += sin(_t * 2.0 + float(gt[2])) * 0.0015
		for m in gt[0]:
			(m as StandardMaterial3D).albedo_color.a = 0.55 + 0.45 * abs(sin(_t * 23.0 + float(gt[2]) + randf() * 0.6))
			(m as StandardMaterial3D).emission_energy_multiplier = 0.9 + 0.9 * randf()

## Radar: anello verde che si allarga dalla navetta.
func radar_fx(pid: int) -> void:
	var at := ship_pos(pid)
	for k in 2:
		var r := _ring(0.3, Color("6dff8a"), 0.02)
		r.position = at - Vector3(0, 0.1, 0)
		_fx.add_child(r)
		var tw := create_tween()
		tw.tween_interval(0.35 * k)
		tw.tween_property(r, "scale", Vector3.ONE * 14.0, 1.4)
		tw.tween_callback(r.queue_free)
