extends SceneTree
## Ion Tails: gara di sole CPU, poi replay; misura la durata e scatta qualche immagine.
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func wait(t: float) -> void:
	await create_timer(t).timeout

func _run() -> void:
	await wait(0.5)
	var idx: int = main.course_files.find("res://data/courses/nutcracker.json")
	if idx >= 0: main.course_idx = idx
	main.choice_secs = 0
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	while main.game == null or not main.game.over:
		await wait(0.5)
	await wait(1.0)
	var t0 := Time.get_ticks_msec()
	main.start_replay()
	var k := 0
	while main.phase == "replay":
		await wait(0.35)
		if k < 40 and k % 4 == 1:
			root.get_texture().get_image().save_png("/tmp/shots/rp_%02d.png" % k)
		k += 1
	print("STTEST replay ", main.game.history.size(), " turni in ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit()
