extends SceneTree
## Ion Tails: screenshot dell'onda del blast ionico e dell'arpione.
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()
func wait(t: float) -> void:
	await create_timer(t).timeout
func shot(n: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("/tmp/shots/fx_%s.png" % n)
func _run() -> void:
	await wait(1.0)
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	for i in 200:
		if main.phase == "energy": break
		await wait(0.1)
	await wait(1.5)
	main.board.blast_fx(2, 1, false, 1)
	main.board.blast_fx(2, 3, true, 0)
	await wait(0.35)
	await shot("blast")
	main.board.hook_fx(0, 4, 2, true)
	await wait(0.3)
	await shot("hook")
	quit()
