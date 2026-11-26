class_name SegmentFx
extends RefCounted
## Effetti 3D delle caratteristiche fanmade dei rettilinei (si possono sommare): pendenza,
## vento (scie, neve sollevata, manica a vento), sabbia (nevicata e cumuli), vetro
## (lucido e luccichii), officina (con il fumo); il bivio; il terreno di neve attorno alla pista.

const HUT_GLB := "res://assets/models/hut.glb"
static var _mats := {}

## Riferimento di una tessera: centro, direzione di marcia, lato destro, lunghezza, mezza larghezza.
static func frame(c: Course, pi: int) -> Dictionary:
	var pc: Dictionary = c.pieces[pi]
	var a: Vector2 = pc["entry_mid"]
	var b: Vector2 = pc["exit_mid"]
	var d := (b - a).normalized()
	return {"a": a, "b": b, "mid": (a + b) * 0.5, "dir": d, "right": Vector2(-d.y, d.x),
		"len": (b - a).length(), "half": c.lane_w * 2.5}

## Nodo orientato sulla tessera: X locale = senso di marcia, Z locale = destra;
## sulle salite e discese è inclinato come il pendio.
static func anchor(c: Course, pi: int, at: Vector2, y_off := 0.0, tilt := true) -> Node3D:
	var f := frame(c, pi)
	var n := Node3D.new()
	n.position = BoardView3D.to3(at, y_off)
	var d: Vector2 = f["dir"]
	var pc: Dictionary = c.pieces[pi]
	var a := atan2(float(pc["h1"]) - float(pc["h0"]), f["len"] * BoardView3D.S) if tilt else 0.0
	n.basis = Basis(Vector3.UP, atan2(-d.y, d.x)) * Basis(Vector3(0, 0, 1), a)
	return n

static func build(parent: Node3D, c: Course) -> void:
	for pi in c.pieces.size():
		var pc: Dictionary = c.pieces[pi]
		var mods: Dictionary = pc["mods"]
		var kinds := []
		var sl := String(mods.get("slope", ""))
		if sl != "":
			parent.add_child(_band(c, pi, sl, 0.016))
			kinds.append(sl)
		if String(mods.get("wind", "")) != "":
			parent.add_child(_band(c, pi, "wind", 0.018, String(mods["wind"]) == "L", String(mods["wind"]) in ["F", "C"]))
			_wind(parent, c, pi)
			kinds.append("wind")
		if mods.get("ice", false):
			parent.add_child(_band(c, pi, "ice", 0.02))
			_ice(parent, c, pi)
			kinds.append("ice")
		if mods.get("fresh", false):
			_fresh(parent, c, pi)
			kinds.append("fresh")
		if mods.get("hut", false):
			_hut(parent, c, pi)
			kinds.append("hut")
		if not kinds.is_empty():
			_signs(parent, c, pi, kinds)
		if String(pc["face"].get("type", "")) == "fork":
			_fork(parent, c, pi)
		# cumuli di sabbia su qualunque tessera ne abbia (sabbia, bivio)
		for id in pc["cells"]:
			if c.fresh.has(id):
				_mounds(parent, c, pi)
				break

# ---------- livelli dipinti e cartelli ----------
static var _tex := {}
static func _fan_tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := "res://assets/fan/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]

## Livello trasparente steso sulla fascia delle corsie, che segue il pendio della tessera.
static func _band(c: Course, pi: int, kind: String, y_off: float, flip := false, along := false) -> MeshInstance3D:
	var f := frame(c, pi)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 16
	var S := BoardView3D.S
	for i in nu:
		for q in [[i, 0], [i + 1, 0], [i + 1, 1], [i, 0], [i + 1, 1], [i, 1]]:
			var u := float(q[0]) / nu
			var v := float(q[1])
			var p2: Vector2 = f["a"] + (f["b"] - f["a"]) * u + f["right"] * (v * 2.0 - 1.0) * f["half"]
			if along:
				# vento a favore o contrario: le scie corrono lungo la pista
				st.set_uv(Vector2(v, u * 3.0))
			else:
				st.set_uv(Vector2(u, 1.0 - v if flip else v))
			st.add_vertex(Vector3(p2.x * S, c.piece_height(pi, p2) + y_off, p2.y * S))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = _fan_tex(kind)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Cartelli all'ingresso, come quelli delle curve: doppia linea rossa e un disco per ogni
## caratteristica, sui due bordi della pista.
static func _signs(parent: Node3D, c: Course, pi: int, kinds: Array) -> void:
	var f := frame(c, pi)
	var S := BoardView3D.S
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("c8322a")
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for off in [4.0, 10.0]:
		var at: Vector2 = f["a"] + f["dir"] * off
		var root := anchor(c, pi, at, 0.024)
		parent.add_child(root)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.004, (f["half"] * 2.0 + 16.0) * S)
		bar.mesh = bm
		bar.material_override = red
		root.add_child(bar)
	for side in [-1.0, 1.0]:
		for k in kinds.size():
			var at: Vector2 = f["a"] + f["dir"] * (c.cell_len * 0.32 + k * c.lane_w * 1.15) + f["right"] * side * (f["half"] + c.lane_w * 0.18)
			var root := anchor(c, pi, at, 0.03)
			parent.add_child(root)
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.58, 0.58)
			q.mesh = pm
			var m := StandardMaterial3D.new()
			m.albedo_texture = _fan_tex("sign_" + String(kinds[k]))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			q.material_override = m
			# il simbolo si legge stando sulla pista, rivolto verso chi arriva
			q.rotation.y = -PI * 0.5
			root.add_child(q)

# ---------- materiali ----------
static func _flake_mat(alpha := 0.9) -> StandardMaterial3D:
	var key := "flake%f" % alpha
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SnowFx.flake_texture()
	m.albedo_color = Color(1, 1, 1, alpha)
	_mats[key] = m
	return m

static func _fade_ramp(peak := 1.0) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, peak))
	g.add_point(0.75, Color(1, 1, 1, peak))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	return g

# ---------- vento ----------
static func _wind(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var wk := String(c.pieces[pi]["mods"].get("wind", "R"))
	var along := wk in ["F", "C"]
	# di lato: +z a destra; lungo la pista: +x a favore (verso di marcia), −x contro
	var side := 1.0 if wk in ["R", "F"] else -1.0
	var force: int = Course.wind_force(c.pieces[pi]["mods"])
	var L: float = f["len"] * BoardView3D.S
	var W: float = f["half"] * 2.0 * BoardView3D.S
	var root := anchor(c, pi, f["mid"], 0.0)
	parent.add_child(root)
	# scie bianche veloci, di traverso alla pista
	var streak := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, 0.55)
	streak.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.96, 0.74, 0.5, 0.75)   # sabbia sollevata dalla tempesta
	streak.material_override = sm
	streak.amount = 40 + 30 * force
	streak.lifetime = 1.1
	streak.preprocess = 2.0
	streak.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	if along:
		bm.size = Vector3(0.55, 0.018, 0.018)
		streak.emission_box_extents = Vector3(L * 0.3, 0.22, W * 0.5)
		streak.position = Vector3(-side * L * 0.25, 0.35, 0)
		streak.direction = Vector3(side, 0, 0)
	else:
		streak.emission_box_extents = Vector3(L * 0.5, 0.22, W * 0.35)
		streak.position = Vector3(0, 0.35, -side * W * 0.45)
		streak.direction = Vector3(0, 0, side)
	streak.spread = 6.0
	streak.gravity = Vector3.ZERO
	streak.initial_velocity_min = 2.4 + 0.8 * force
	streak.initial_velocity_max = 3.6 + 1.0 * force
	streak.color_ramp = _fade_ramp(0.8)
	streak.local_coords = true
	root.add_child(streak)
	# neve sollevata: sbuffi bassi che corrono sulla pista
	var dust := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	dust.mesh = qm
	var dm := _flake_mat(0.6).duplicate() as StandardMaterial3D
	dm.albedo_color = Color(0.9, 0.62, 0.4, 0.6)
	dust.material_override = dm
	dust.amount = 60 + 40 * force
	dust.lifetime = 2.2
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(L * 0.5, 0.04, W * 0.6)
	dust.position = Vector3(0, 0.06, 0)
	dust.direction = Vector3(side, 0.35, 0) if along else Vector3(0, 0.35, side)
	dust.spread = 18.0
	dust.gravity = Vector3(0, -0.4, 0)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.4
	dust.color_ramp = _fade_ramp(0.7)
	dust.local_coords = true
	root.add_child(dust)
	# manica a vento sul lato da cui soffia, gonfia e svolazzante verso dove va il vento
	var at: Vector2 = f["mid"] + f["dir"] * f["len"] * 0.3 - f["right"] * side * (f["half"] + c.lane_w * 1.1)
	if along:
		at = f["mid"] - f["dir"] * f["len"] * 0.3 + f["right"] * (f["half"] + c.lane_w * 1.1)
	var holder := anchor(c, pi, at, 0.0)
	parent.add_child(holder)
	var sock := Windsock.new()
	sock.side = 1.0 if along else side
	if along:
		# la manica punta lungo la pista: avanti col vento a favore, indietro col contrario
		sock.rotation.y = PI * 0.5 * side
	sock.scale = Vector3.ONE * 1.6
	holder.add_child(sock)

# ---------- sabbia ----------
static func _fresh(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var L: float = f["len"] * BoardView3D.S
	var W: float = f["half"] * 2.0 * BoardView3D.S
	var root := anchor(c, pi, f["mid"], 0.0)
	parent.add_child(root)
	var fall := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	fall.mesh = qm
	fall.material_override = _flake_mat(0.95)
	fall.amount = 420
	fall.lifetime = 4.5
	fall.preprocess = 5.0
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(L * 0.55, 0.2, W * 0.75)
	fall.position = Vector3(0, 2.6, 0)
	fall.direction = Vector3(0.15, -1, 0.1)
	fall.spread = 12.0
	fall.gravity = Vector3(0, -0.25, 0)
	fall.initial_velocity_min = 0.45
	fall.initial_velocity_max = 0.8
	fall.scale_amount_min = 0.5
	fall.scale_amount_max = 1.3
	fall.tangential_accel_min = -0.3
	fall.tangential_accel_max = 0.3
	fall.color_ramp = _fade_ramp(1.0)
	fall.local_coords = true
	root.add_child(fall)


## Cumuli di sabbia sulle caselle segnate: piccoli rilievi morbidi che sfumano nella pista.
static func _mounds(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	# la pista è disegnata senza luci: il cumulo, illuminato, va un po' scurito per non abbagliare
	m.albedo_color = Color(0.78, 0.5, 0.32)
	var rng := RandomNumberGenerator.new()
	rng.seed = pi * 31 + 7
	var d3 := Vector3(f["dir"].x, 0, f["dir"].y)
	var r3 := Vector3(f["right"].x, 0, f["right"].y)
	var cl: float = c.cell_len * BoardView3D.S
	var lw: float = c.lane_w * BoardView3D.S
	for id in c.pieces[pi]["cells"]:
		if not c.fresh.has(id):
			continue
		var base: Vector3 = BoardView3D.to3(c.cells[id]["pos"], 0.006)
		var bumps := []
		for k in 3:
			bumps.append([rng.randf_range(-0.35, 0.35), rng.randf_range(-0.3, 0.3), rng.randf_range(0.25, 0.4), rng.randf_range(0.08, 0.13)])
		var n := 12
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var grid := []
		for j in n + 1:
			var row := []
			for i in n + 1:
				var u := float(i) / n * 2.0 - 1.0
				var v := float(j) / n * 2.0 - 1.0
				var h := 0.0
				for bp in bumps:
					var du: float = (u - bp[0]) / bp[2] * 0.5
					var dv: float = (v - bp[1]) / bp[2] * 0.5
					h += bp[3] * exp(-(du * du + dv * dv) * 1.6)
				var rr := sqrt(u * u + v * v)
				var edge: float = smoothstep(1.0, 0.35, rr)
				var pos := base + d3 * u * cl * 0.62 + r3 * v * lw * 0.62 + Vector3.UP * h * edge
				row.append([pos, Color(1, 1, 1, clamp(edge * 1.6, 0.0, 1.0))])
			grid.append(row)
		for j in n:
			for i in n:
				for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
					var vv: Array = grid[q[1]][q[0]]
					st.set_color(vv[1])
					st.add_vertex(vv[0])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		# il cumulo è costruito già al suo posto: per spazzarlo via lo si schiaccia attorno al centro
		mi.set_meta("snow_cell", id)
		mi.set_meta("snow_center", base)
		parent.add_child(mi)

# ---------- vetro ----------
static func _ice(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	var root := anchor(c, pi, f["mid"], 0.014)
	parent.add_child(root)
	var pm := PlaneMesh.new()
	pm.size = Vector2(f["len"] * BoardView3D.S, f["half"] * 2.0 * BoardView3D.S)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.92, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic_specular = 1.0
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.05
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# luccichii che compaiono e svaniscono sul vetro
	var gl := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	gl.mesh = qm
	gl.material_override = _flake_mat(1.0)
	gl.amount = 26
	gl.lifetime = 1.4
	gl.preprocess = 1.5
	gl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	gl.emission_box_extents = Vector3(pm.size.x * 0.5, 0.0, pm.size.y * 0.5)
	gl.position = Vector3(0, 0.02, 0)
	gl.gravity = Vector3.ZERO
	gl.initial_velocity_max = 0.0
	gl.scale_amount_min = 0.3
	gl.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	gl.color_ramp = g
	gl.local_coords = true
	root.add_child(gl)

# ---------- bivio: abeti sull'isola di neve in mezzo alla pista ----------
static func _fork(parent: Node3D, c: Course, pi: int) -> void:
	var pc: Dictionary = c.pieces[pi]
	var xf: Transform2D = pc["xf"]
	var models := []
	for k in [1, 2]:
		var path := "res://assets/models/sapling%s.glb" % ("" if k == 1 else "_%d" % k)
		if ResourceLoader.exists(path):
			models.append(load(path))
	if models.is_empty():
		return
	var i := 0
	for pt in pc["face"].get("island", []):
		var at := xf * FaceDB.v2(pt)
		for off in [-0.25, 0.25]:
			var t: Node3D = (models[i % models.size()] as PackedScene).instantiate()
			BoardView3D._vertex_color_material(t)
			t.scale = Vector3.ONE * (1.1 + 0.25 * float(i % 3) / 2.0)
			var d: Vector2 = pc["exit_mid"] - pc["entry_mid"]
			var p2: Vector2 = at + d.normalized() * c.cell_len * off
			t.position = BoardView3D.to3(p2, 0.0)
			t.rotation.y = float(i) * 1.7
			parent.add_child(t)
			i += 1

# ---------- officina ----------
static func _hut(parent: Node3D, c: Course, pi: int) -> void:
	var f := frame(c, pi)
	for id in c.pieces[pi]["cells"]:
		if not c.huts.has(id):
			continue
		var cp: Vector2 = c.cells[id]["pos"]
		var out: Vector2 = f["right"] if (cp - f["mid"]).dot(f["right"]) > 0 else -f["right"]
		var at: Vector2 = cp + out * c.lane_w * 2.2
		var holder := anchor(c, pi, at, 0.0)
		parent.add_child(holder)
		var hut := _workshop()
		holder.add_child(hut)
		# l'ingresso verso la pista
		hut.rotation.y = atan2(out.x, out.y) - holder.rotation.y + PI
		# fumo dal camino
		var sm := CPUParticles3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.16)
		sm.mesh = qm
		var mat := _flake_mat(0.55).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(0.82, 0.85, 0.9, 0.5)
		sm.material_override = mat
		sm.amount = 24
		sm.lifetime = 3.0
		sm.preprocess = 3.0
		sm.position = Vector3(0, 0.95, 0)
		sm.direction = Vector3(0.15, 1, 0)
		sm.spread = 10.0
		sm.gravity = Vector3(0.12, 0.1, 0)
		sm.initial_velocity_min = 0.2
		sm.initial_velocity_max = 0.35
		sm.scale_amount_min = 0.6
		sm.scale_amount_max = 1.0
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 1.8))
		sm.scale_amount_curve = sc
		sm.color_ramp = _fade_ramp(0.9)
		holder.add_child(sm)
		holder.set_meta("smoke", sm)

## Officina di riparazione: hangar a cupola con antenna e luci.
static func _workshop() -> Node3D:
	var n := Node3D.new()
	var steel := TeamModel.metal(Color("8c96a3"), 0.5)
	var dark := TeamModel.metal(Color("39414c"), 0.6)
	var base := MeshInstance3D.new()
	base.mesh = TeamModel.box(0.7, 0.28, 0.5)
	base.material_override = steel
	base.position.y = 0.14
	n.add_child(base)
	var dome := MeshInstance3D.new()
	dome.mesh = TeamModel.cyl(0.25, 0.25, 0.7, 16)
	dome.material_override = dark
	dome.rotation.z = PI / 2
	dome.scale = Vector3(1, 1, 0.8)
	dome.position.y = 0.28
	n.add_child(dome)
	var door := MeshInstance3D.new()
	door.mesh = TeamModel.box(0.3, 0.22, 0.02)
	door.material_override = TeamModel.glow(Color("ffb066"), 0.7)
	door.position = Vector3(0, 0.12, -0.26)
	n.add_child(door)
	var ant := MeshInstance3D.new()
	ant.mesh = TeamModel.cyl(0.01, 0.01, 0.5, 6)
	ant.material_override = steel
	ant.position = Vector3(0.25, 0.6, 0.1)
	n.add_child(ant)
	var bl := MeshInstance3D.new()
	bl.mesh = TeamModel.sph(0.03)
	bl.material_override = TeamModel.glow(Color("4ef0c8"), 1.2)
	bl.position = Vector3(0.25, 0.86, 0.1)
	n.add_child(bl)
	return n

static func _prop(path: String, height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps = load(path)
	if not (ps is PackedScene):
		return null
	var n: Node3D = (ps as PackedScene).instantiate()
	var root := Node3D.new()
	root.add_child(n)
	# i modelli sono già ridotti, centrati e appoggiati a terra con altezza 1
	root.scale = Vector3.ONE * height
	return root

# ---------- fiancate di neve sotto le tessere rialzate ----------
static func _skirt(c: Course, pi: int) -> MeshInstance3D:
	var pc: Dictionary = c.pieces[pi]
	var f := frame(c, pi)
	var half: float = f["half"] + c.lane_w * 1.2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var top_c := Color("b0623a")
	var bot_c := Color("6a3020")
	for sgn in [-1.0, 1.0]:
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var p0: Vector2 = f["a"] + (f["b"] - f["a"]) * t0 + f["right"] * sgn * half
			var p1: Vector2 = f["a"] + (f["b"] - f["a"]) * t1 + f["right"] * sgn * half
			var h0: float = c.piece_height(pi, p0) - 0.004
			var h1: float = c.piece_height(pi, p1) - 0.004
			var a := Vector3(p0.x * BoardView3D.S, h0, p0.y * BoardView3D.S)
			var b := Vector3(p1.x * BoardView3D.S, h1, p1.y * BoardView3D.S)
			var a2 := Vector3(a.x, -0.03, a.z)
			var b2 := Vector3(b.x, -0.03, b.z)
			var nrm := Vector3(f["right"].x * sgn, 0.25, f["right"].y * sgn).normalized()
			for v in [[a, top_c], [b, top_c], [b2, bot_c], [a, top_c], [b2, bot_c], [a2, bot_c]]:
				st.set_normal(nrm)
				st.set_color(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## Manica a vento: palo di legno e cono a strisce arancioni e bianche che sbatte nel vento.
class Windsock:
	extends Node3D
	var side := 1.0
	var _segs: Array = []
	var _t := 0.0
	func _ready() -> void:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("7b5232")
		wood.roughness = 0.9
		var pole := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.018
		pc.bottom_radius = 0.024
		pc.height = 0.9
		pc.radial_segments = 8
		pole.mesh = pc
		pole.material_override = wood
		pole.position.y = 0.45
		add_child(pole)
		var orange := StandardMaterial3D.new()
		orange.albedo_color = Color("ef6b1f")
		orange.roughness = 0.8
		var white := StandardMaterial3D.new()
		white.albedo_color = Color("f4f4f2")
		white.roughness = 0.8
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.86, 0)
		add_child(pivot)
		var r := 0.075
		var prev := pivot
		for i in 5:
			var seg := Node3D.new()
			seg.position = Vector3(0, 0, 0) if i == 0 else Vector3(0, 0, 0.11 * side)
			prev.add_child(seg)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = r
			cm.bottom_radius = r * 0.86
			cm.height = 0.11
			cm.radial_segments = 12
			cm.cap_top = false
			cm.cap_bottom = false
			mi.mesh = cm
			mi.material_override = orange if i % 2 == 0 else white
			# il cilindro è verticale: lo stendiamo lungo Z (verso dove soffia il vento)
			mi.rotation.x = PI * 0.5 * side
			mi.position = Vector3(0, 0, 0.055 * side)
			seg.add_child(mi)
			_segs.append(seg)
			prev = seg
			r *= 0.86
	func _process(delta: float) -> void:
		_t += delta
		for i in _segs.size():
			var sg: Node3D = _segs[i]
			var k := float(i + 1)
			sg.rotation.y = sin(_t * 7.0 - k * 0.9) * 0.06 * k
			sg.rotation.x = -0.05 * k * 0.5 + sin(_t * 5.0 - k * 1.2) * 0.03 * k


# ---------- terreno: argine di neve intorno alla pista, con i declivi ai lati ----------
const T_FLAT := 1.45     # distanza dalla casella più vicina fino a cui il terreno sta alla quota della pista
const T_SLOPE := 0.5     # larghezza della parete del canyon
const T_STEP := 0.2      # passo della griglia
const T_GROUND := -0.025
const WALL_H := 1.25     # altezza delle pareti del canyon sopra la pista
const T_ALBEDO := Color(1, 1, 1)
const GROUND_TINT := Color("8a4a2a")
## Fasce di colore della roccia (dal basso in alto): arenaria, ocra, ruggine, scura.
const STRATA := [Color("7a3a22"), Color("a4552e"), Color("8e4426"), Color("c27a45"), Color("6a3020"), Color("b0623a"), Color("5a2a1c")]

static func _strata(h: float, n: float) -> Color:
	var x: float = (h + n * 0.08) / 0.14
	var i := int(floor(x))
	var a: Color = STRATA[posmod(i, STRATA.size())]
	var b: Color = STRATA[posmod(i + 1, STRATA.size())]
	var t: float = clamp((x - floor(x) - 0.75) / 0.25, 0.0, 1.0)
	return a.lerp(b, t)

## Terreno a canyon: ogni punto prende la quota della tessera della casella più vicina, poi
## si alza in una parete a strati fino all'altopiano. Sul bordo, i nidi dei cecchini
## (le posizioni finiscono nel metadato "nests" del nodo restituito).
static func terrain(c: Course) -> Node3D:
	var root := Node3D.new()
	root.set_meta("nests", [])
	if c.cells.is_empty():
		return root
	var S := BoardView3D.S
	var bucket := {}
	var bs := 2.5
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for cc in c.cells:
		var w: Vector2 = cc["pos"] * S
		mn = mn.min(w)
		mx = mx.max(w)
		var k := Vector2i(floor(w.x / bs), floor(w.y / bs))
		if not bucket.has(k):
			bucket[k] = []
		bucket[k].append(cc["id"])
	var reach := T_FLAT + T_SLOPE
	var margin := reach + 2.4
	mn -= Vector2.ONE * margin
	mx += Vector2.ONE * margin
	var nx := int(ceil((mx.x - mn.x) / T_STEP)) + 1
	var nz := int(ceil((mx.y - mn.y) / T_STEP)) + 1
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.55
	var big := FastNoiseLite.new()
	big.seed = 77
	big.frequency = 0.12
	var hs := PackedFloat32Array()
	var fs := PackedFloat32Array()
	var ns := PackedFloat32Array()
	hs.resize(nx * nz)
	fs.resize(nx * nz)
	ns.resize(nx * nz)
	var rb := 1     # celle da 2,5: i vicini coprono almeno 2,5 di raggio, più della parete
	var base_h := 0.0
	for j in nz:
		for i in nx:
			var w := Vector2(mn.x + i * T_STEP, mn.y + j * T_STEP)
			var kb := Vector2i(floor(w.x / bs), floor(w.y / bs))
			var best := -1
			var bd := INF
			for dj in range(-rb, rb + 1):
				for di in range(-rb, rb + 1):
					var lst = bucket.get(kb + Vector2i(di, dj))
					if lst == null:
						continue
					for id in lst:
						var d: float = (c.cells[id]["pos"] * S).distance_squared_to(w)
						if d < bd:
							bd = d
							best = id
			var nn := noise.get_noise_2d(w.x, w.y)
			var nb := big.get_noise_2d(w.x, w.y)
			var top := base_h
			if best >= 0:
				top = c.piece_height(int(c.cells[best]["piece"]), w / S) - 0.03
			var d := sqrt(bd) if best >= 0 else 99.0
			# bordo irregolare: la parete comincia un po' prima o un po' dopo
			var edge := T_FLAT + nb * 0.25
			var t: float = clamp((d - edge) / T_SLOPE, 0.0, 1.0)
			var f: float = 1.0 - (t * t * (3.0 - 2.0 * t))    # 1 sulla pista, 0 sull'altopiano
			var wall := WALL_H + nb * 0.35 + nn * 0.06
			var h: float = top + (1.0 - f) * wall
			if f > 0.98:
				h = top - 0.01 + nn * 0.01
			# terrazzini sulla parete
			h += sin(f * PI) * nn * 0.08
			hs[j * nx + i] = h
			fs[j * nx + i] = f
			ns[j * nx + i] = nn
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz - 1:
		for i in nx - 1:
			var ids := [j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i]
			for q in [0, 1, 2, 0, 2, 3]:
				var id: int = ids[q]
				var ii := id % nx
				var jj := id / nx
				var col := _strata(hs[id], ns[id])
				if fs[id] > 0.97:
					col = Color("8a4a2a").lerp(Color("a35a34"), 0.5 + ns[id] * 0.5)
				elif fs[id] < 0.02:
					col = col.lerp(Color("b86a3c"), 0.35)
				st.set_color(col)
				st.add_vertex(Vector3(mn.x + ii * T_STEP, hs[id], mn.y + jj * T_STEP))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.albedo_color = T_ALBEDO
	mi.material_override = m
	root.add_child(mi)
	# altopiano oltre la griglia: quattro grandi riquadri attorno, alla quota del ciglio
	var far := SurfaceTool.new()
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := WALL_H - 0.06
	var x0 := mn.x + T_STEP
	var z0 := mn.y + T_STEP
	var x1 := mn.x + (nx - 2) * T_STEP
	var z1 := mn.y + (nz - 2) * T_STEP
	var B := 300.0
	for r in [[x0 - B, z0 - B, x1 + B, z0], [x0 - B, z1, x1 + B, z1 + B], [x0 - B, z0, x0, z1], [x1, z0, x1 + B, z1]]:
		var a := Vector3(r[0], y, r[1])
		var b := Vector3(r[2], y, r[1])
		var cc := Vector3(r[2], y, r[3])
		var d := Vector3(r[0], y, r[3])
		for v in [a, b, cc, a, cc, d]:
			far.set_normal(Vector3.UP)
			far.add_vertex(v)
	var fm := MeshInstance3D.new()
	fm.mesh = far.commit()
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("9a5634")
	fmat.roughness = 1.0
	fm.material_override = fmat
	root.add_child(fm)
	_nests(root, c, hs, fs, nx, nz, mn)
	_hoodoos(root, hs, fs, nx, nz, mn)
	return root

## Posizioni dei nidi dei cecchini: sul ciglio del canyon, distanziati.
static func _nests(root: Node3D, c: Course, hs: PackedFloat32Array, fs: PackedFloat32Array, nx: int, nz: int, mn: Vector2) -> void:
	var pts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for j in range(2, nz - 2, 3):
		for i in range(2, nx - 2, 3):
			var id := j * nx + i
			if fs[id] > 0.03 or fs[id] < 0.0:
				continue
			# appena oltre il ciglio: un vicino ancora in parete
			var rim := false
			for o in [-3, 3, -3 * nx, 3 * nx]:
				var k: int = id + o
				if k >= 0 and k < fs.size() and fs[k] > 0.15:
					rim = true
			if not rim:
				continue
			var p := Vector3(mn.x + i * T_STEP, hs[id], mn.y + j * T_STEP)
			var ok := true
			for q in pts:
				if (q as Vector3).distance_to(p) < 3.2:
					ok = false
					break
			if ok:
				pts.append(p)
	var parent := Node3D.new()
	root.add_child(parent)
	var steel := TeamModel.metal(Color("4a525e"), 0.6)
	var eye := TeamModel.glow(Color("ff4a3a"), 1.2)
	for p in pts:
		var n := Node3D.new()
		n.position = p
		parent.add_child(n)
		var b := MeshInstance3D.new()
		b.mesh = TeamModel.cyl(0.07, 0.1, 0.08, 8)
		b.material_override = steel
		b.position.y = 0.04
		n.add_child(b)
		var dome := MeshInstance3D.new()
		dome.mesh = TeamModel.sph(0.065)
		dome.material_override = steel
		dome.position.y = 0.085
		n.add_child(dome)
		var barrel := MeshInstance3D.new()
		barrel.mesh = TeamModel.cyl(0.012, 0.012, 0.16, 6)
		barrel.material_override = steel
		barrel.rotation.x = PI / 2
		barrel.position = Vector3(0, 0.1, -0.08)
		n.add_child(barrel)
		var l := MeshInstance3D.new()
		l.mesh = TeamModel.sph(0.016)
		l.material_override = eye
		l.position = Vector3(0, 0.13, -0.03)
		n.add_child(l)
		n.set_meta("barrel", barrel)
	root.set_meta("nests", pts)
	root.set_meta("nest_nodes", parent.get_children())

## Pinnacoli di roccia sparsi sull'altopiano.
static func _hoodoos(root: Node3D, hs: PackedFloat32Array, fs: PackedFloat32Array, nx: int, nz: int, mn: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mm_x := []
	for j in range(1, nz - 1, 4):
		for i in range(1, nx - 1, 4):
			var id := j * nx + i
			if fs[id] > 0.01 or rng.randf() > 0.06:
				continue
			var sc := rng.randf_range(0.6, 1.5)
			var pos := Vector3(mn.x + i * T_STEP + rng.randf_range(-0.1, 0.1), hs[id] - 0.02, mn.y + j * T_STEP + rng.randf_range(-0.1, 0.1))
			mm_x.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.8), sc)), pos))
	if mm_x.is_empty():
		return
	var mesh := TeamModel.cyl(0.06, 0.12, 0.5, 7)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = mm_x.size()
	for k in mm_x.size():
		mm.set_instance_transform(k, mm_x[k].translated_local(Vector3(0, 0.25, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = TeamModel.mat(Color("7c3f24"), 1.0)
	root.add_child(mmi)

## Abeti sparsi sui declivi (MultiMesh: tanti alberi con poco costo).
static func _slope_trees(root: Node3D, c: Course, hs: PackedFloat32Array, fs: PackedFloat32Array, nx: int, nz: int, mn: Vector2) -> void:
	var path := "res://assets/models/sapling.glb"
	if not ResourceLoader.exists(path):
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		inst.free()
		return
	var src := found[0] as MeshInstance3D
	var mesh := src.mesh
	var base_xf := src.global_transform if src.is_inside_tree() else src.transform
	inst.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xfs := []
	for j in range(1, nz - 1, 2):
		for i in range(1, nx - 1, 2):
			var id := j * nx + i
			var f := fs[id]
			if f < 0.22 or f > 0.72 or rng.randf() > 0.13:
				continue
			var sc := rng.randf_range(0.9, 1.6)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			var pos := Vector3(mn.x + i * T_STEP + rng.randf_range(-0.12, 0.12), hs[id] - 0.03, mn.y + j * T_STEP + rng.randf_range(-0.12, 0.12))
			xfs.append(Transform3D(b, pos) * base_xf)
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 0.9
	mmi.material_override = tm
	root.add_child(mmi)
