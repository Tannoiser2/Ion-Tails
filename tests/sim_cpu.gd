extends SceneTree
## Ion Tails: gara completa con la scena vera (solo CPU), a turni o simultanea (ST_SIM=1).
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func wait(t: float) -> void:
	await create_timer(t).timeout

func _run() -> void:
	await wait(0.5)
	main.sim_variant = OS.get_environment("ST_SIM") == "1"
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400000:
		await wait(0.5)
		if main.game != null and main.game.over:
			break
	var line := []
	for r in main.game.results:
		line.append("%s %s" % [r["p"].name, r["st"]])
	print("STTEST fine giri ", main.game.round_n, " over ", main.game.over, " | ", " | ".join(line))
	quit()
