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
	print("STTEST gadget ", "OK" if ok else "ERRORI")
	quit()
