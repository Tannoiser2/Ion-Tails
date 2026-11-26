extends SceneTree
## Ion Tails: rendering per copertina e icona (le navette in partenza nel canyon, senza interfaccia).
## xvfb-run godot --path . --resolution 1200x1200 -s res://tests/ion_cover.gd
var main
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func wait(t: float) -> void:
	await create_timer(t).timeout

func _run() -> void:
	await wait(1.0)
	var idx := -1
	for i in main.course_files.size():
		if String(main.course_files[i]).ends_with("nutcracker.json"): idx = i
	if idx >= 0: main.course_idx = idx
	main.setup_on = [true, true, true, true, true]
	main.setup_ai = [true, true, true, true, true]
	main.start_game()
	for i in 200:
		if main.phase == "energyAI" or main.phase == "reveal": break
		await wait(0.1)
	main.race_id += 1
	main.hud.visible = false
	main._close_modal()
	var b = main.board
	b.set_follow(false)
	b.show_al = false
	var c: Vector2 = main.course.cells[main.course.start_cells[2]]["pos"]
	var h: Vector2 = main.course.heading(main.course.start_cells[2])
	b.target_goal = BoardView3D.to3(c + h * 60.0, 0.0)
	b.target = b.target_goal
	b.yaw_goal = BoardView3D.yaw_of(h)
	b.yaw = b.yaw_goal
	b.dist_goal = 2.2
	b.dist = 2.2
	b.pitch = deg_to_rad(20)
	main.set_process(false)
	await wait(2.0)
	var img := root.get_texture().get_image()
	img.save_png("/tmp/shots/cover_raw.png")
	b.dist_goal = 1.2
	b.dist = 1.2
	b.pitch = deg_to_rad(28)
	b.target_goal = BoardView3D.to3(c, 0.1)
	b.target = b.target_goal
	b.yaw_goal = BoardView3D.yaw_of(h) + 0.6
	b.yaw = b.yaw_goal
	await wait(1.5)
	root.get_texture().get_image().save_png("/tmp/shots/icon_raw.png")
	quit()
