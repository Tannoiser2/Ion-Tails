extends SceneTree
## Ion Tails: galleria delle navette sul finto Firebase (tests/firebase_mock.py).
func _init() -> void:
	_run()
func _run() -> void:
	var net := Net.new()
	root.add_child(net)
	await process_frame
	await process_frame
	var c := ShipBuild.sanitize(ShipBuild.PRESETS[2])
	c["name"] = "Falco del deserto"
	var r := await ShipBuild.publish(net, c, "Stefano")
	print("pubblica ", r)
	var g := await ShipBuild.gallery(net)
	print("galleria ", g["ok"], " ", g["list"].size(), " ", g["list"][0]["name"] if g["list"].size() > 0 else "", " mia ", g["list"][0].get("mine") if g["list"].size() > 0 else "")
	var ok: bool = r.get("ok", false) and g["ok"] and g["list"].size() == 1 and int(g["list"][0]["cfg"]["hull"]) == 2
	var d := await ShipBuild.unpublish(net, str(r.get("id", "")))
	var g2 := await ShipBuild.gallery(net)
	ok = ok and d and g2["list"].is_empty()
	print("STTEST galleria ", "OK" if ok else "ERRORI")
	quit()
