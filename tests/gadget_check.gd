extends SceneTree
## Ion Tails: controlli mirati dei gadget (invisibilità, radar, scudo, missile, mine).
func _init() -> void:
	var c := Course.new()
	c.load_file("res://data/courses/nutcracker.json")
	var g := SledGame.new()
	g.setup(c, [false, true, true, true, true], 7)
	for p in g.players:
		g.take_slot(p, g.free_slots()[0])
	g.deal_all()
	var ok := true
	g.energy_round_start()
	var me = g.players[0]
	g.apply_alloc(me, {"iv": 1, "ra": 1, "sh": 1})
	print("energia dopo la scelta ", me.energy, " al ", me.al)
	if not g.invisible(me): print("ERRORE invisibilità"); ok = false
	# mina altrui 8 passi davanti: il radar la vede
	var t: int = me.cell
	for i in 8:
		t = int(c.cells[t]["fwd"][0])
	g.mines[t] = g.players[1].id
	if not g.sees_mine(me, t): print("ERRORE radar"); ok = false
	if g.sees_mine(g.players[2], t): print("ERRORE: senza radar la vede"); ok = false
	# cecchino contro scudo: probabilità ridotta
	print("mira cecchino 2 punti: senza scudo ", g.sniper_chance(2, 5, 0, 0), " con scudo 1: ", g.sniper_chance(2, 5, 0, 1))
	# invisibile: il cecchino non la trova
	g.players[1].al = {"sn": 2, "snt": me.id}
	var o := {"path": [int(c.cells[me.cell]["fwd"][0])], "end": int(c.cells[me.cell]["fwd"][0]), "from": me.cell, "dents": 0, "speed": 3}
	var msgs := []
	g._gadgets_after_move(me, o, msgs)
	print("cecchino su invisibile: ", msgs, " mezzi danni ", o.get("ghalf", 0))
	if int(o.get("ghalf", 0)) != 0: ok = false
	g.round_n += 1
	if g.invisible(me): print("ERRORE: invisibile anche al turno dopo con 1 punto"); ok = false
	# --- arpione, blast, CME: navette messe a mano
	g.round_n += 2
	var lane := -1
	for i in c.cells.size():
		var ci: Dictionary = c.cells[i]
		if int(ci["togo"]) > 25 and int(ci.get("side_l", -1)) >= 0 and int(ci.get("side_r", -1)) >= 0:
			var ok6 := true
			var x := i
			for k in 6:
				x = g._straight(x)
				if x < 0 or int(c.cells[x].get("side_r", -1)) < 0 or g._straight_back(x) < 0:
					ok6 = false
					break
			if ok6:
				lane = i
				break
	for p in g.players:
		p.cell = -1
		p.al = {}
	var a = g.players[0]
	var b = g.players[1]
	a.cell = lane
	var bc: int = lane
	for i in 3:
		bc = g._straight(bc)
	b.cell = bc
	var togo0 := int(c.cells[b.cell]["togo"])
	a.al = {"ho": 2}
	var hk := g.apply_hooks()
	print("arpione: ", hk.size(), " indietro di ", int(c.cells[b.cell]["togo"]) - togo0)
	if int(c.cells[b.cell]["togo"]) - togo0 != 2: print("ERRORE arpione"); ok = false
	# blast: una navetta a fianco e una davanti
	a.al = {"bl": 1}
	var side_c := int(c.cells[lane].get("side_l", -1))
	b.cell = side_c
	var cc = g.players[2]
	cc.cell = g._straight(lane)
	var b0: int = b.cell
	var c0: int = cc.cell
	var o2 := {"path": [lane], "end": lane, "from": lane, "dents": 0, "speed": 3}
	var m2 := []
	g._gadgets_after_move(a, o2, m2)
	print("blast: ", m2)
	if b.cell == b0 and b.dents == 0 and not b.half: print("ERRORE blast a fianco"); ok = false
	if cc.cell == c0 and not cc.half: print("ERRORE blast davanti"); ok = false
	# CME: il missile deviato va verso la navetta nella corsia accanto
	for p in g.players:
		p.cell = -1
		p.al = {}
		p.half = false
		p.dents = 0
	a.cell = lane
	b.cell = g._straight(g._straight(lane))
	b.al = {"cm": 1}
	var side2 := int(c.cells[b.cell].get("side_r", -1))
	cc.cell = g._straight(side2)
	var m3 := []
	var r3 := g._missile(a, lane, 7, m3)
	print("CME: ", m3, " ", r3.get("res"), " su ", r3.get("pid"))
	if r3.get("pid", -1) != cc.id: print("ERRORE CME verso la navetta vicina"); ok = false
	# --- nuovi gadget
	for p in g.players:
		p.cell = -1
		p.al = {}
		p.half = false
		p.dents = 0
		p.mounted = SledGame.GADGET_ORDER.duplicate()
	# esca contro il missile
	a.cell = lane
	b.cell = g._straight(g._straight(lane))
	b.al = {"ec": 1}
	var m4 := []
	var r4 := g._missile(a, lane, 7, m4)
	print("esca: ", m4, " ", r4.get("res"))
	if r4.get("res") != "decoy" or b.half: print("ERRORE esca"); ok = false
	# ancora contro l'arpione
	b.al = {"an": 1}
	a.al = {"ho": 2}
	var bc0: int = b.cell
	g.apply_hooks()
	if b.cell != bc0: print("ERRORE ancora"); ok = false
	# sifone
	a.al = {"si": 2}
	a.energy = 0
	b.energy = 5
	var sp := g.apply_siphons()
	print("sifone: ", a.energy, " ", b.energy)
	if a.energy != 3 or b.energy != 2: print("ERRORE sifone"); ok = false
	# EMP: spegne lo scudo di chi è vicino
	a.al = {"em": 1}
	b.cell = g._straight(lane)
	b.al = {"sh": 2, "cm": 1}
	var o5 := {"path": [lane], "end": lane, "from": lane, "dents": 0, "speed": 3}
	var m5 := []
	g._gadgets_after_move(a, o5, m5)
	print("emp: ", m5, " ", b.al)
	if b.al.has("sh"): print("ERRORE emp"); ok = false
	# scia di sabbia
	a.al = {"sc": 1}
	var p6 := [g._straight(lane), g._straight(g._straight(lane)), g._straight(g._straight(g._straight(lane)))]
	b.cell = -1
	var o6 := {"path": p6, "end": p6[2], "from": lane, "dents": 0, "speed": 3}
	var f0: int = g.fresh.size()
	g._gadgets_after_move(a, o6, [])
	print("scia: ", g.fresh.size() - f0)
	if g.fresh.size() - f0 != 2: print("ERRORE scia"); ok = false
	for t6 in p6: g.fresh.erase(t6)
	g.fresh.erase(lane)
	# nanobot
	a.cell = lane
	a.dents = 2
	a.al = {"nb": 2}
	var o7 := {"path": [], "end": lane, "from": lane, "dents": 0, "corner_dents": 0, "speed": 0, "crash": "", "sap": []}
	g.after_move(a, o7)
	print("nanobot: danni ", a.dents, " mezzo ", a.half)
	if a.dents != 1: print("ERRORE nanobot"); ok = false
	# salto: una navetta subito davanti non ferma
	a.al = {"sa": 1}
	a.dents = 0
	b.cell = g._straight(lane)
	var outs := g.compute_outs(a, {"L": 2, "R": 2, "B": 1})
	var far := false
	for oo in outs:
		if (oo["path"] as Array).has(b.cell) and int(oo["end"]) != b.cell:
			far = true
	print("salto: scavalca ", far)
	if not far: print("ERRORE salto"); ok = false
	print("STTEST gadget ", "OK" if ok else "ERRORI")
	quit()
