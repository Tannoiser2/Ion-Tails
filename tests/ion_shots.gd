extends SceneTree
## Ion Tails: screenshot del menu, della fase dell'energia, della rivelazione e di una mossa.
## xvfb-run godot --path . --resolution 1280x800 -s res://tests/ion_shots.gd -- <prefisso>
var main
var pre := "land"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		pre = a[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/shots/%s_%s.png" % [pre, name])

func wait(t: float) -> void:
	await create_timer(t).timeout

func until(ph: Array, n := 120) -> void:
	for i in n:
		if main.phase in ph: return
		await wait(0.2)

func _run() -> void:
	await wait(1.0)
	await shot("01_menu")
	var idx := -1
	for i in main.course_files.size():
		if String(main.course_files[i]).ends_with("nutcracker.json"): idx = i
	if idx >= 0: main.course_idx = idx
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [false, true, true, true, true]
	main.start_game()
	await until(["slots"])
	await wait(0.6)
	await shot("02_slots")
	main._take_slot(main.game.free_slots()[0])
	await until(["energy"])
	await wait(1.0)
	await shot("03_energy")
	main.en_draft = {"mi": 1, "bo": 1, "sn": 2, "snt": main.game.players[1].id}
	main._refresh()
	await wait(0.3)
	await shot("04_energy_sel")
	main._energy_confirm()
	await until(["cards"])
	await wait(1.2)
	await shot("06_cards")
	main._tap_card(main.cur.hand.size() - 1)
	main._tap_slot("L")
	main._confirm()
	await wait(0.6)
	await shot("07_dest")
	main.board.laser_fx(main.game.players[2].id, "hit")
	main.board.laser_fx(main.game.players[1].id, "shield")
	await wait(0.12)
	await shot("07b_laser")
	if main.phase == "dest":
		main._apply_choice(main.pending.duplicate(), main.outs[main.outs.size() - 1])
	await until(["energy", "cards", "discard"], 300)
	await wait(0.8)
	await shot("08_next")
	main.board.set_follow(false)
	main.board.dist_goal = 9.0
	main.board.pitch = deg_to_rad(35)
	await wait(1.5)
	await shot("09_wide")
	# mine viste col radar (prova del modello)
	var mc := []
	for p in main.game.players:
		var fw: Array = main.course.cells[p.cell]["fwd"]
		if not fw.is_empty(): mc.append(fw[0])
	main.board.mine_cells = mc
	main.board.redraw()
	main.board.dist_goal = 3.0
	main.board.target_goal = BoardView3D.to3(main.course.cells[mc[0]]["pos"])
	main.board.explosion_fx(mc[0])
	main.board.emp_fx(main.game.players[1].cell)
	await wait(1.4)
	await shot("10_mines")
	quit()
