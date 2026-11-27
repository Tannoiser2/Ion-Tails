extends SceneTree
## Ion Tails: fotogrammi dell'arpione (partenza, aggancio, traino).
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()
func wait(t: float) -> void:
	await create_timer(t).timeout
func shot(n: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("/tmp/shots/hook_%s.png" % n)
func _run() -> void:
	await wait(1.0)
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	for i in 200:
		if main.phase == "energy": break
		await wait(0.1)
	await wait(1.5)
	main.race_id += 1000
	var g = main.game
	var a = g.players[3]
	var t = g.hook_target(a)
	if t == null:
		print("nessun bersaglio"); quit(); return
	a.al = {"ho": 2}
	var old: int = t.cell
	for p in g.players:
		if p != a: p.al.erase("ho")
	var hk = g.apply_hooks()
	print("hook ", hk.size(), " togo ", g.cell(old)["togo"], "->", g.cell(t.cell)["togo"], " hooker togo ", g.cell(a.cell)["togo"])
	var pa = main.board.ship_pos(a.id)
	var pb = main.board.ship_pos(t.id)
	main.board.frame([Vector2(pa.x, pa.z) / main.board.S, Vector2(pb.x, pb.z) / main.board.S, g.cell(t.cell)["pos"]], 5.5, true)
	main.board.yaw_goal = main.board.yaw_of(main.board._heading_of(a.cell))
	main.board.hook_fx(a.id, t.id, 2, true)
	for i in 6:
		await wait(0.25)
		await shot(str(i))
	quit()
