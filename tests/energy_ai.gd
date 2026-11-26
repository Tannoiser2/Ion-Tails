extends SceneTree
## Prova senza grafica (Ion Tails): partite complete con sole CPU, energia e gadget.
## godot --headless --path . -s res://tests/energy_ai.gd -- res://data/courses/<pista>.json [partite]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := "res://data/courses/nutcracker.json" if args.is_empty() else args[0]
	var ng := 6 if args.size() < 2 else int(args[1])
	var c := Course.new()
	if not c.load_file(path):
		print("ERRORE: ", c.error)
		quit(1)
		return
	var tot := {}
	var wrecks := 0
	var rounds := 0
	for g in ng:
		var game := SledGame.new()
		game.setup(c, [true, true, true, true, true])
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
				assert(game.alloc_ok(p, a))
				game.apply_alloc(p, a)
				for k in a:
					tot[k] = tot.get(k, 0) + 1
			for p in game.race_order():
				if not game.racing(p): continue
				if p.hand.is_empty():
					game.add_dent(p, 1)
					if p.wrecked: continue
					game.draw_up(p)
				var ch := game.ai_choose(p)
				var m := game.mat_after(p, ch["pend"])
				game.log_text = game.describe(ch["pend"], ch["o"], m)
				game.commit_play(p, ch["pend"])
				for t in ch["o"]["path"]:
					p.cell = t
				game.after_move(p, ch["o"])
				if g == 0 and safety <= 4:
					print("  ", p.name, ": ", game.log_text)
			game.check_round_end()
		var line := []
		for r in game.results:
			line.append("%s %s (danni %d, energia spesa %d)" % [r["p"].name, r["st"], r["p"].dents, r["p"].spent])
			if r["st"] == "distrutta": wrecks += 1
		rounds += game.round_n
		print("gara %d, %d giri, mine rimaste %d: %s" % [g + 1, game.round_n, game.mines.size(), " | ".join(line)])
	print("gadget usati: ", tot, "  distrutte: ", wrecks, "  giri medi: ", float(rounds) / ng)
	quit(0)
