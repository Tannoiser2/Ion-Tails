class_name Workshop
extends VBoxContainer
## Officina: si costruisce la propria navetta (nome, modello, scafo, motori, batteria, gadget)
## con ShipBuild.CREDITS crediti. Si salva sul dispositivo e si può pubblicare nella galleria
## online, da cui si prendono le navette degli altri.

signal closed

var main                       # la scena principale (campi di testo, token, rete)
var land := true
var cfg: Dictionary = {}       # navetta in costruzione
var view := "build"            # "build" oppure "gallery"
var msg := ""
var _gal: Array = []
var _gal_state := ""           # "", "loading", "ok", "error"
var _preview: SledThumb
var _preview_model := -99
var _name_le: LineEdit

func _init(m, is_land: bool, start: Dictionary = {}) -> void:
	main = m
	land = is_land
	cfg = ShipBuild.sanitize(start) if not start.is_empty() else ShipBuild.standard()
	if int(cfg.get("model", -1)) < 0:
		cfg["model"] = 0
	if str(cfg.get("name", "")) == "Di serie":
		cfg["name"] = "La mia navetta"
	add_theme_constant_override("separation", 12)
	_build()

func _rebuild() -> void:
	# l'anteprima 3D resta la stessa (non si ricarica il modello a ogni tocco)
	if _preview and _preview.get_parent():
		_preview.get_parent().remove_child(_preview)
	UIKit.clear(self)
	_build()
	if main.has_method("_fit_modal"):
		main._fit_modal()

func _build() -> void:
	if view == "gallery":
		_build_gallery()
		return
	# intestazione: titolo e crediti rimasti
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var t := UIKit.title("Officina", 44)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var left := ShipBuild.left(cfg)
	var cl := UIKit.label("crediti\nrimasti", 14, UIKit.MUTED)
	cl.autowrap_mode = TextServer.AUTOWRAP_OFF
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cl)
	var cn: Label = main._big("%d" % left, 46, UIKit.ENERGY if left > 0 else UIKit.MUTED)
	cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cn)
	var cd := UIKit.label("di %d" % ShipBuild.CREDITS, 14, UIKit.MUTED)
	cd.autowrap_mode = TextServer.AUTOWRAP_OFF
	cd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cd)
	add_child(head)
	var cols: BoxContainer = HBoxContainer.new() if land else VBoxContainer.new()
	cols.add_theme_constant_override("separation", 24 if land else 12)
	add_child(cols)
	# --- colonna dell'astronave: anteprima, nome, modello
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 8)
	lc.custom_minimum_size = Vector2(360 if land else 0, 0)
	cols.add_child(lc)
	var m := int(cfg.get("model", 0))
	if _preview == null or _preview_model != m:
		if _preview:
			_preview.queue_free()
		_preview = SledThumb.new(SledGame.COLORS[m], 360, 190, m)
		_preview.spin = 0.6
		_preview.fit_mul = 1.9
		_preview_model = m
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := PanelContainer.new()
	pv.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.25), 14, UIKit.LINE, 1, 4))
	pv.add_child(_preview)
	lc.add_child(pv)
	lc.add_child(UIKit.heading("Nome"))
	_name_le = main._line_edit("nome della navetta", 24)
	_name_le.text = str(cfg.get("name", ""))
	_name_le.text_changed.connect(func(t: String): cfg["name"] = t.strip_edges())
	_name_le.custom_minimum_size = Vector2(0, 48)
	lc.add_child(_name_le)
	lc.add_child(UIKit.heading("Modello"))
	var mg := GridContainer.new()
	mg.columns = 2 if land else 3
	mg.add_theme_constant_override("h_separation", 6)
	mg.add_theme_constant_override("v_separation", 6)
	for i in ShipBuild.MODELS.size():
		var b := _small_btn(ShipBuild.MODELS[i], i == m, SledGame.COLORS[i])
		b.pressed.connect(func():
			cfg["model"] = i
			_rebuild())
		mg.add_child(b)
	lc.add_child(mg)
	lc.add_child(_stats_box())
	# --- colonna delle parti
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 8)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rc)
	_part_row(rc, "Scafo", "hull", ShipBuild.HULLS, 1, 5)
	_part_row(rc, "Mazzo dei motori (le tue 20 carte)", "eng", ShipBuild.ENGINES, 1, 3)
	_part_row(rc, "Tipo di motori (come guidi)", "mt", ShipBuild.MOTOR_TYPES, 1, 2, 0)
	_part_row(rc, "Batteria", "bat", ShipBuild.BATTERIES, 1, 3)
	var gh := HBoxContainer.new()
	var ghl := UIKit.heading("Gadget montati (1 credito l'uno)")
	ghl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(ghl)
	rc.add_child(gh)
	var g: Array = cfg.get("g", [])
	for cat in SledGame.CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for k in SledGame.GADGET_ORDER:
			if String(SledGame.GADGETS[k][1]) != cat:
				continue
			row.add_child(_gadget_toggle(k, g.has(k), left))
		rc.add_child(row)
	# --- modelli pronti e navette salvate
	add_child(_presets_row())
	add_child(_saved_box())
	if msg != "":
		var ml := UIKit.label(msg, 16, UIKit.HEAD)
		add_child(ml)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var bs := UIKit.cta("Salva")
	bs.pressed.connect(_save)
	var bp := UIKit.button("Pubblica")
	bp.pressed.connect(_publish)
	var bg := UIKit.button("Galleria")
	bg.pressed.connect(func():
		view = "gallery"
		_load_gallery())
	var bc := UIKit.button("Chiudi")
	bc.pressed.connect(func(): closed.emit())
	for b in [bs, bp, bg, bc]:
		b.custom_minimum_size = Vector2(0, 56)
		acts.add_child(b)
	add_child(acts)

## Riga di tre schede (scafo, motori o batteria): nome, costo e descrizione.
func _part_row(parent: Control, title: String, key: String, opts: Array, cost_i: int, desc_i: int, def := 1) -> void:
	parent.add_child(UIKit.heading(title))
	var row := GridContainer.new()
	row.columns = opts.size() if (land or opts.size() <= 3) else 3
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var cur := int(cfg.get(key, def))
	for i in opts.size():
		var o: Array = opts[i]
		var on := i == cur
		var trial := cfg.duplicate(true)
		trial[key] = i
		var ok := ShipBuild.cost(trial) <= ShipBuild.CREDITS
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(150 if opts.size() <= 3 else 110, (84 if land else 100) if opts.size() <= 3 else 100)
		b.disabled = not on and not ok
		_style_choice(b, on)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -8
		v.offset_top = 6
		v.offset_bottom = -6
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl := UIKit.label(String(o[0]), 18, UIKit.INK if not b.disabled else UIKit.MUTED)
		nl.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(nl)
		var c := int(o[cost_i])
		var cl := UIKit.label("%d cr" % c if c > 0 else "gratis", 14, UIKit.ENERGY if on else UIKit.MUTED)
		cl.autowrap_mode = TextServer.AUTOWRAP_OFF
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(cl)
		v.add_child(top)
		var dl := UIKit.label(String(o[desc_i]), 13, UIKit.MUTED)
		dl.custom_minimum_size = Vector2(120, 0)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(dl)
		b.pressed.connect(func():
			cfg[key] = i
			_rebuild())
		row.add_child(b)
	parent.add_child(row)

func _style_choice(b: Button, on: bool) -> void:
	if on:
		UIKit.style_button(b, Color(UIKit.ACCENT, 0.22), UIKit.INK, UIKit.ACCENT, 3, 12)
	else:
		UIKit.style_button(b, Color(UIKit.SOFT, 0.92), UIKit.INK, UIKit.LINE, 1, 12)

func _small_btn(text: String, on: bool, col := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
	if on:
		UIKit.style_button(b, Color(col if col.a > 0 else UIKit.ACCENT, 0.35), UIKit.INK, col if col.a > 0 else UIKit.ACCENT, 3, 10)
	else:
		UIKit.style_button(b, Color(UIKit.SOFT, 0.92), UIKit.INK, Color(col, 0.5) if col.a > 0 else UIKit.LINE, 1, 10)
	return b

## Il token del gadget: acceso se montato.
func _gadget_toggle(k: String, on: bool, left: int) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(110, 44)
	b.tooltip_text = "%s: %s" % [SledGame.gadget_name(k), SledGame.GADGETS[k][2]]
	b.disabled = not on and left < ShipBuild.GADGET_COST
	_style_choice(b, on)
	var t := TextureRect.new()
	t.texture = main._gadget_tex(k)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 4
	t.offset_right = -4
	t.offset_top = 3
	t.offset_bottom = -3
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = Color(1, 1, 1, 1) if on else Color(0.45, 0.48, 0.55, 0.7)
	b.add_child(t)
	b.pressed.connect(func():
		var g: Array = (cfg.get("g", []) as Array).duplicate()
		if g.has(k):
			g.erase(k)
		else:
			g.append(k)
		cfg["g"] = g
		_rebuild())
	return b

## Le caratteristiche in gara, in parole semplici.
func _stats_box() -> Control:
	var hull: Array = ShipBuild.HULLS[int(cfg["hull"])]
	var eng: Array = ShipBuild.ENGINES[int(cfg["eng"])]
	var bat := ShipBuild.battery(cfg)
	var cm := ShipBuild.curve_mod(cfg)
	var cnt: Array = eng[2]
	var lines := [
		"Distrutta al [b]%d°[/b] danno, [b]%d[/b] carte in mano" % [int(hull[2]) + 1, ShipBuild.hand_max(cfg)],
		"Curve: [b]%s[/b]" % ("+%d al limite" % cm if cm > 0 else ("%d al limite" % cm if cm < 0 else "limite normale")),
		"Carte da 1 a 5: [b]%d, %d, %d, %d, %d[/b]" % cnt,
		"Motori: [b]%s[/b]" % String(ShipBuild.MOTOR_TYPES[ShipBuild.motor(cfg)][0]).to_lower(),
		"Punti gadget: [b]%s[/b]" % ("normali" if bat == 0 else ("%+d" % bat)),
	]
	var r := UIKit.rich(15)
	r.text = "\n".join(lines)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.SOFT, 0.7), 10, UIKit.LINE, 1, 10))
	p.add_child(r)
	return p

func _presets_row() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UIKit.heading("Modelli pronti"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for p in ShipBuild.PRESETS:
		var b := _small_btn(String(p["name"]), false)
		b.custom_minimum_size = Vector2(150, 40)
		b.size_flags_horizontal = 0
		var pc: Dictionary = p
		b.pressed.connect(func():
			var c := ShipBuild.sanitize(pc)
			if int(c["model"]) < 0:
				c["model"] = int(cfg.get("model", 0))
			c["name"] = str(pc["name"]) if str(pc["name"]) != "Di serie" else "La mia navetta"
			cfg = c
			msg = "Modello «%s» caricato: cambialo come vuoi." % pc["name"]
			_rebuild())
		row.add_child(b)
	v.add_child(row)
	return v

func _saved_box() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var list := ShipBuild.load_local()
	v.add_child(UIKit.heading("Le mie navette (%d)" % list.size()))
	if list.is_empty():
		v.add_child(UIKit.label("Nessuna navetta salvata: costruiscila e premi «Salva».", 15, UIKit.MUTED))
		return v
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, min(list.size(), 3) * 50)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 4)
	sc.add_child(lv)
	for c in list:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var nl := UIKit.label("%s" % c["name"], 17, UIKit.INK if str(c.get("id", "")) != str(cfg.get("id", "-")) else UIKit.HEAD)
		nl.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(150, 0)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nl)
		if land:
			var sl := UIKit.label(ShipBuild.summary(c), 13, UIKit.MUTED)
			sl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sl.clip_text = true
			sl.custom_minimum_size = Vector2(200, 0)
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(sl)
		var b1 := _small_btn("Carica", false)
		b1.custom_minimum_size = Vector2(100, 40)
		b1.size_flags_horizontal = 0
		var cc: Dictionary = c
		b1.pressed.connect(func():
			cfg = cc.duplicate(true)
			msg = "«%s» caricata." % cc["name"]
			_rebuild())
		r.add_child(b1)
		var b2 := _small_btn("Elimina", false)
		b2.custom_minimum_size = Vector2(100, 40)
		b2.size_flags_horizontal = 0
		b2.pressed.connect(func():
			ShipBuild.remove_local(str(cc.get("id", "")))
			if str(cfg.get("id", "")) == str(cc.get("id", "")):
				cfg.erase("id")
			msg = "«%s» eliminata dal dispositivo." % cc["name"]
			_rebuild())
		r.add_child(b2)
		lv.add_child(r)
	v.add_child(sc)
	return v

func _current() -> Dictionary:
	if str(cfg.get("name", "")) == "":
		cfg["name"] = "Navetta senza nome"
	return cfg

func _save() -> void:
	var s := ShipBuild.store(_current())
	cfg = s
	msg = "«%s» salvata sul dispositivo: la trovi nella scelta delle navette del menu." % s["name"]
	_rebuild()

func _publish() -> void:
	var c := ShipBuild.store(_current())
	cfg = c
	msg = "Pubblico «%s» nella galleria…" % c["name"]
	_rebuild()
	var author: String = main._player_name() if main.has_method("_player_name") else ""
	var r: Dictionary = await ShipBuild.publish(main._net(), c, author)
	if r.get("ok", false):
		cfg["gid"] = r["id"]
		ShipBuild.store(cfg)
		msg = "«%s» è nella galleria online: tutti possono prenderla." % c["name"]
	else:
		msg = "Non riesco a pubblicare: %s" % r.get("error", "")
	if is_inside_tree():
		_rebuild()

func _load_gallery() -> void:
	_gal_state = "loading"
	_rebuild()
	var r: Dictionary = await ShipBuild.gallery(main._net())
	_gal = r.get("list", [])
	_gal_state = "ok" if r.get("ok", false) else "error"
	if not r.get("ok", false):
		msg = "Galleria non raggiungibile: %s" % r.get("error", "")
	if is_inside_tree() and view == "gallery":
		_rebuild()

func _build_gallery() -> void:
	var head := HBoxContainer.new()
	var t := UIKit.title("Galleria", 44)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	add_child(head)
	add_child(UIKit.label("Le navette costruite e pubblicate dai giocatori. «Prendi» la copia tra le tue navette.", 16, UIKit.MUTED))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 430 if land else 620)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 6)
	sc.add_child(lv)
	if _gal_state == "loading":
		lv.add_child(UIKit.label("Carico la galleria…", 18, UIKit.MUTED))
	elif _gal_state == "error":
		lv.add_child(UIKit.label(msg, 16, UIKit.MUTED))
	elif _gal.is_empty():
		lv.add_child(UIKit.label("La galleria è ancora vuota: pubblica la prima navetta!", 18, UIKit.MUTED))
	for e in _gal:
		var c: Dictionary = e["cfg"]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.SOFT, 0.85), 12, SledGame.COLORS[max(0, int(c.get("model", 0)))], 2, 10))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		p.add_child(r)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var nl := UIKit.label(str(e["name"]), 20, UIKit.INK)
		nl.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(200, 0)
		info.add_child(nl)
		var by := str(e.get("author", ""))
		var sl := UIKit.label(("di %s · " % by if by != "" else "") + ShipBuild.MODELS[max(0, int(c.get("model", 0)))], 14, UIKit.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		sl.clip_text = true
		sl.custom_minimum_size = Vector2(200, 0)
		info.add_child(sl)
		var s2 := UIKit.label(ShipBuild.summary(c), 14, UIKit.MUTED)
		s2.custom_minimum_size = Vector2(200, 0)
		info.add_child(s2)
		r.add_child(info)
		var bt := _small_btn("Prendi", false)
		bt.custom_minimum_size = Vector2(110, 46)
		bt.size_flags_horizontal = 0
		bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ee: Dictionary = e
		bt.pressed.connect(func():
			var cc: Dictionary = (ee["cfg"] as Dictionary).duplicate(true)
			cc["name"] = str(ee["name"])
			cc.erase("id")
			if str(ee.get("author", "")) != "":
				cc["author"] = str(ee["author"])
			cfg = ShipBuild.store(cc)
			view = "build"
			msg = "«%s» presa dalla galleria e salvata tra le tue navette." % cc["name"]
			_rebuild())
		r.add_child(bt)
		if e.get("mine", false):
			var bd := _small_btn("Togli", false)
			bd.custom_minimum_size = Vector2(100, 46)
			bd.size_flags_horizontal = 0
			bd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bd.pressed.connect(func():
				msg = ""
				if await ShipBuild.unpublish(main._net(), str(ee["id"])):
					_load_gallery()
				else:
					msg = "Non riesco a toglierla dalla galleria."
					_rebuild())
			r.add_child(bd)
		lv.add_child(p)
	add_child(sc)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	var br := UIKit.button("Aggiorna")
	br.pressed.connect(_load_gallery)
	var bb := UIKit.cta("Torna all'officina")
	bb.pressed.connect(func():
		view = "build"
		msg = ""
		_rebuild())
	for b in [br, bb]:
		b.custom_minimum_size = Vector2(0, 56)
		acts.add_child(b)
	add_child(acts)
