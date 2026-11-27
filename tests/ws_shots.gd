extends SceneTree
## Ion Tails: screenshot del menu con la scelta delle navette e dell'officina.
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
	var c := ShipBuild.sanitize(ShipBuild.PRESETS[2])
	c["name"] = "Falco del deserto"
	ShipBuild.store(c)
	main.setup_ship[1] = ShipBuild.load_local()[0]
	main.setup_ship[2] = ShipBuild.sanitize(ShipBuild.PRESETS[1])
	main._menu_thumbs = []
	main.show_menu()
	await wait(1.0)
	await shot("m1_menu")
	main.show_workshop()
	await wait(1.2)
	await shot("m2_officina")
	var ws = main.modal_root.find_children("*", "Workshop", true, false)[0]
	ws.cfg = ShipBuild.sanitize(ShipBuild.PRESETS[3])
	ws.cfg["name"] = "Scheggia"
	ws.msg = "Modello «Sprinter» caricato: cambialo come vuoi."
	ws._rebuild()
	await wait(1.0)
	await shot("m3_officina2")
	ws._gal = [{"id": "a", "name": "Falco del deserto", "author": "Stefano", "cfg": c, "ts": 1, "mine": true},
		{"id": "b", "name": "Vespa nera", "author": "Luca", "cfg": ShipBuild.sanitize(ShipBuild.PRESETS[4]), "ts": 0, "mine": false}]
	ws._gal_state = "ok"
	ws.view = "gallery"
	ws._rebuild()
	await wait(0.8)
	await shot("m4_galleria")
	quit()
