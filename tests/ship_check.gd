extends SceneTree
## Ion Tails: officina. Controlla costi e validazione delle navette e fa correre i modelli pronti
## uno contro l'altro (sole CPU, senza grafica) per vedere se sono equilibrati.
## godot --headless --path . -s res://tests/ship_check.gd -- [partite]

func _init() -> void:
	var ok := true
	for p in ShipBuild.PRESETS:
		var c := ShipBuild.sanitize(p)
		print("%-10s costo %d  %s" % [p["name"], ShipBuild.cost(c), ShipBuild.summary(c)])
		if ShipBuild.cost(c) > ShipBuild.CREDITS or str(c["name"]) != str(p["name"]):
			print("ERRORE preset ", p["name"]); ok = false
	# troppo cara: torna di serie
	var cheat := {"name": "Barone", "hull": 2, "eng": 2, "bat": 2, "g": SledGame.GADGET_ORDER}
	if str(ShipBuild.sanitize(cheat)["name"]) != "Di serie": print("ERRORE: navetta troppo cara accettata"); ok = false
	var js := ShipBuild.to_json(ShipBuild.PRESETS[2])
	if ShipBuild.from_json(js)["hull"] != 2: print("ERRORE json"); ok = false
	var args := OS.get_cmdline_user_args()
	var ng := 10 if args.is_empty() else int(args[0])
	var paths := ["res://data/courses/nutcracker.json"]
	var wins := {}
	var pts := {}
	var wrecks := {}
	for g in ng:
		var c := Course.new()
		c.load_file(paths[g % paths.size()])
		var game := SledGame.new()
		# ogni modello pronto su un colore diverso, a rotazione
		var ships := {}
		for i in 5:
			ships[str(i)] = ShipBuild.PRESETS[(i + g) % 5]
		game.setup(c, [true, true, true, true, true], 0, ships)
		for p in game.players:
			var fs := game.free_slots()
			game.take_slot(p, fs[randi() % fs.size()])
		game.deal_all()
		var safety := 0
		while not game.over and safety < 200:
			safety += 1
			game.energy_round_start()
			for p in game.race_order():
				var a := game.ai_alloc(p)
				for k in SledGame.GADGET_ORDER:
					if a.has(k) and not p.mounted.has(k):
						print("ERRORE: gadget non montato ", k); ok = false
				game.apply_alloc(p, a)
			game.apply_hooks()
			for p in game.race_order():
				if not game.racing(p): continue
				if p.hand.is_empty():
					game.add_dent(p, 1)
					if p.wrecked: continue
					game.draw_up(p)
				var ch := game.ai_choose(p)
				game.commit_play(p, ch["pend"])
				for t in ch["o"]["path"]:
					p.cell = t
				game.after_move(p, ch["o"])
			game.check_round_end()
		var n := game.results.size()
		for k in n:
			var r = game.results[k]
			var nm := str(r["p"].ship["name"])
			pts[nm] = pts.get(nm, 0) + (n - 1 - k)
			if k == 0: wins[nm] = wins.get(nm, 0) + 1
			if r["st"] == "distrutta": wrecks[nm] = wrecks.get(nm, 0) + 1
	print("vittorie ", wins)
	print("punti ", pts)
	print("distrutte ", wrecks)
	print("STTEST navette ", "OK" if ok else "ERRORI")
	quit()
