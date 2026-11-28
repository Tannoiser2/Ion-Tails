extends SceneTree
## Ion Tails: screenshot delle pagine del menu (home, gara, editor, entra, regole).
var main
var pre := "land"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		pre = a[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()
func wait(t: float) -> void:
	await create_timer(t).timeout
func shot(n: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/shots/%s_%s.png" % [pre, n])
func _run() -> void:
	await wait(1.0)
	ShipBuild.save_local([])
	main.show_menu()
	await wait(0.8)
	await shot("p1_home")
	main.show_race_setup()
	await wait(1.2)
	await shot("p2_gara")
	main._menu_set_seat(1, "online")
	main._menu_set_seat(2, "phone")
	main._menu_set_seat(3, "human")
	await wait(0.6)
	await shot("p3_gara_online")
	if not main._wide():
		main._race_step("ships")
		await wait(0.5)
		await shot("p3b_navette")
		main._race_step("game")
		await wait(0.5)
		await shot("p3c_partita")
	main.show_editor_hub()
	await wait(0.8)
	await shot("p4_editor")
	main.show_join_room()
	await wait(0.8)
	await shot("p5_entra")
	main.show_help(false)
	await wait(1.0)
	await shot("p6_regole")
	var rv = main.modal_root.find_children("*", "RulesView", true, false)[0]
	for sct in ["ui", "gadget", "shop", "room", "track"]:
		rv.show_section(sct)
		await wait(0.6)
		await shot("p7_" + sct)
		if sct == "ui":
			for k in [1, 2, 3]:
				rv._scroll.scroll_vertical = 650 * k
				await wait(0.3)
				await shot("p7_ui_%d" % k)
	quit()
