class_name TeamModel
extends Node3D
## Navetta di Ion Tails costruita in codice: un abitacolo trainato da due motori affiancati,
## uniti all'abitacolo da cavi e fra loro da un arco di energia. Muso (motori) verso −Z,
## lunghezza circa 0,85 unità, sospesa sopra la pista. Al posto della muta di Snow Tails.

var run := 0.0            # 0 = ferma, 1 = in corsa
var slope := 0.0          # pendenza del terreno sotto la navetta (salite e discese)
var _shake := 0.0
var _t := 0.0
var _phase := 0.0
var _rig: Node3D = null           # tutto ciò che fluttua
var _engines: Array = []          # [nodo, fase]
var _flames: Array = []           # MeshInstance3D delle fiamme (scalate con la corsa)
var _arc: MeshInstance3D = null
var _arc_mat: StandardMaterial3D = null
var _cables: Array = []           # [MeshInstance3D, nodo motore, attacco sull'abitacolo]
var _pod: Node3D = null
var _shield: MeshInstance3D = null
var _shield_mat: StandardMaterial3D = null
var shield_on := false
var team_color := Color.WHITE

const HOVER := 0.11
const ENG_X := 0.125
const ENG_Z := -0.24
const POD_Z := 0.26

static func mat(c: Color, rough := 0.85, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.9
	return m

static func metal(c: Color, rough := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.55
	m.metallic_specular = 0.35
	return m

static func glow(c: Color, energy := 1.2, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _part(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi

static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c

static func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func cyl(r_top: float, r_bot: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	return c

func build(team: Color) -> void:
	team_color = team
	_phase = randf() * TAU
	_rig = Node3D.new()
	add_child(_rig)
	_rig.position.y = HOVER
	var hull := metal(Color("8d99a8"))
	var dark := metal(Color("2b323d"), 0.6)
	var paint := metal(team.darkened(0.05), 0.4)
	var hot := Color("7fe8ff")
	for side in [-1, 1]:
		var e := Node3D.new()
		e.position = Vector3(ENG_X * side, 0.0, ENG_Z)
		_rig.add_child(e)
		# gondola del motore, sdraiata lungo Z
		_part(caps(0.056, 0.36), hull, Vector3.ZERO, Vector3(PI / 2, 0, 0), e)
		# fascia nel colore della squadra e presa d'aria davanti
		_part(cyl(0.059, 0.059, 0.08, 16), paint, Vector3(0, 0, -0.05), Vector3(PI / 2, 0, 0), e)
		_part(cyl(0.046, 0.058, 0.05, 16), dark, Vector3(0, 0, -0.17), Vector3(PI / 2, 0, 0), e)
		_part(cyl(0.028, 0.028, 0.012, 16), glow(Color("1b2733"), 0.0), Vector3(0, 0, -0.196), Vector3(PI / 2, 0, 0), e)
		# alette
		_part(box(0.012, 0.075, 0.13), paint, Vector3(0.0, 0.055, 0.08), Vector3.ZERO, e)
		_part(box(0.09, 0.01, 0.10), hull, Vector3(0.045 * side, -0.01, 0.09), Vector3(0, 0, -0.25 * side), e)
		# ugello e fiamma di plasma
		_part(cyl(0.035, 0.045, 0.05, 16), dark, Vector3(0, 0, 0.205), Vector3(PI / 2, 0, 0), e)
		var fl := _part(cyl(0.0, 0.034, 0.22, 12), glow(hot, 1.4, 0.65), Vector3(0, 0, 0.33), Vector3(PI / 2, 0, 0), e)
		_flames.append(fl)
		_engines.append([e, randf() * TAU])
	# arco di energia fra i due motori (davanti)
	_arc_mat = glow(Color("9af0ff"), 1.6, 0.8)
	_arc = _part(box(ENG_X * 2.0 - 0.09, 0.008, 0.008), _arc_mat, Vector3(0, 0.0, ENG_Z - 0.11), Vector3.ZERO, _rig)
	# abitacolo
	_pod = Node3D.new()
	_pod.position = Vector3(0, 0.0, POD_Z)
	_rig.add_child(_pod)
	var body := _part(caps(0.075, 0.28), paint, Vector3.ZERO, Vector3(PI / 2, 0, 0), _pod)
	body.scale = Vector3(1.15, 1.0, 0.85)
	_part(sph(0.05), glow(Color("2c86a8"), 0.35), Vector3(0, 0.035, -0.04), Vector3.ZERO, _pod).scale = Vector3(0.9, 0.55, 1.5)
	_part(box(0.20, 0.012, 0.07), hull, Vector3(0, -0.01, 0.06), Vector3.ZERO, _pod)
	_part(cyl(0.022, 0.03, 0.04, 12), dark, Vector3(0, 0, 0.135), Vector3(PI / 2, 0, 0), _pod)
	_part(sph(0.018), glow(Color("ffb066"), 1.0), Vector3(0, 0, 0.16), Vector3.ZERO, _pod)
	# cavi dai motori all'abitacolo
	for i in 2:
		var c := MeshInstance3D.new()
		c.mesh = cyl(0.006, 0.006, 1.0, 6)
		c.material_override = glow(team.lightened(0.35), 0.9)
		_rig.add_child(c)
		_cables.append([c, _engines[i][0], Vector3((-1 if i == 0 else 1) * 0.045, 0.01, POD_Z - 0.11)])
	# scudo: bolla trasparente (accesa quando la navetta ha lo scudo)
	_shield_mat = glow(Color("58d8ff"), 0.7, 0.18)
	_shield = _part(sph(0.5), _shield_mat, Vector3(0, 0.02, 0.0), Vector3.ZERO, _rig)
	_shield.scale = Vector3(0.55, 0.35, 0.95)
	_shield.visible = false
	_update_cables()

func set_shield(on: bool) -> void:
	shield_on = on
	if _shield:
		_shield.visible = on

func _update_cables() -> void:
	for cb in _cables:
		var mi: MeshInstance3D = cb[0]
		var e: Node3D = cb[1]
		var a: Vector3 = e.position + Vector3(0, 0.0, 0.17)
		var b: Vector3 = cb[2]
		var mid := (a + b) * 0.5
		var d := b - a
		mi.position = mid
		var up := d.normalized()
		var basis := Basis()
		var x := up.cross(Vector3.FORWARD)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		var z := x.cross(up).normalized()
		basis = Basis(x, up, z)
		mi.basis = basis * Basis.from_scale(Vector3(1, d.length(), 1))

func shake(amount: float) -> void:
	_shake = max(_shake, amount)

func _process(delta: float) -> void:
	_t += delta
	if _rig == null:
		return
	var bob := sin(_t * 2.3 + _phase) * 0.012 + sin(_t * 17.0 + _phase) * 0.003 * run
	_rig.position.y = HOVER + bob
	_rig.rotation.x = -0.06 * run + slope * 0.3
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 1.6)
		_rig.rotation.z = sin(_t * 47.0) * 0.18 * _shake
		_rig.rotation.y = sin(_t * 31.0 + 1.0) * 0.08 * _shake
	else:
		_rig.rotation.z = sin(_t * 1.7 + _phase) * 0.02
		_rig.rotation.y = 0.0
	for e in _engines:
		var n: Node3D = e[0]
		n.position.y = sin(_t * 3.1 + float(e[1])) * 0.008
		n.rotation.z = sin(_t * 2.0 + float(e[1])) * 0.03
	var fl_len := 0.35 + 0.65 * run
	for f in _flames:
		var fm: MeshInstance3D = f
		var flick := 0.9 + 0.1 * sin(_t * 40.0 + fm.get_instance_id())
		fm.scale = Vector3(1.0, fl_len * flick, 1.0)
		fm.position.z = 0.205 + 0.11 * fl_len * flick
	if _arc_mat:
		_arc_mat.emission_energy_multiplier = 1.1 + 0.6 * abs(sin(_t * 23.0)) + run * 0.4
		_arc.position.y = sin(_t * 31.0) * 0.004
	if _shield and _shield.visible:
		_shield_mat.albedo_color.a = 0.14 + 0.05 * sin(_t * 4.0)
	_update_cables()
