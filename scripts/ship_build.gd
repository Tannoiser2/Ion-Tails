class_name ShipBuild
extends RefCounted
## Officina: la navetta di ogni giocatore. Con CREDITS crediti si scelgono scafo, motori,
## batteria e i gadget montati (1 credito ciascuno). In gara si usano solo i gadget montati.
## La configurazione è un dizionario semplice, salvabile in JSON:
## {name, model (0-4), hull (0-2), eng (0-2), bat (0-2), g: [chiavi dei gadget]}

const CREDITS := 15
const MODELS := ["Fenice rossa", "Lama blu", "Vespa gialla", "Mantide verde", "Ombra viola"]
## [nome, costo, danni che regge, modifica al limite delle curve, carte in mano, descrizione]
const HULLS := [
	["Leggero", 0, 3, 0, 5, "fragile: il 4° danno la distrugge"],
	["Medio", 2, 4, 0, 5, "il 5° danno la distrugge, come di serie"],
	["Pesante", 4, 5, 0, 5, "regge un danno in più: il 1° non toglie carte, il 6° la distrugge"],
]
## [nome, costo, quante carte da 1, 2, 3, 4, 5 (20 in tutto), descrizione]
const ENGINES := [
	["Economico", 0, [5, 5, 4, 3, 3], "più carte basse: si va piano ma si curva bene"],
	["Bilanciato", 1, [4, 4, 4, 4, 4], "quattro carte per valore, come di serie"],
	["Turbo", 4, [3, 3, 4, 5, 5], "più carte alte: veloci, ma attenzione alle curve"],
]
## Tipo di motori: come guidi. [nome, costo, descrizione]
const MOTOR_TYPES := [
	["Normali", 0, "nessun effetto, come di serie"],
	["Stabili", 2, "a ogni mossa puoi derivare di una corsia in meno, se ti conviene"],
	["Agili", 2, "in curva troppo forte il primo danno è solo mezzo danno"],
	["Potenti", 2, "+1 alla velocità con i due motori pari, ma con motori diversi derivi di 1 in più"],
	["Ionici", 2, "+1 punto gadget ogni 2 turni"],
]
## [nome, costo, punti gadget in più o in meno, descrizione]
const BATTERIES := [
	["Piccola", 0, -3, "3 punti gadget in meno a inizio gara"],
	["Media", 2, 0, "i punti gadget normali della pista"],
	["Grande", 4, 3, "3 punti gadget in più a inizio gara"],
]
const GADGET_COST := 1
const PRESETS := [
	{"name": "Di serie", "model": -1, "hull": 1, "eng": 1, "mt": 0, "bat": 1, "g": ["sn", "mi", "ms", "sh", "ra", "cm", "iv", "bo", "ho", "bl"]},
	{"name": "Predatore", "model": 0, "hull": 0, "eng": 2, "mt": 3, "bat": 1, "g": ["sn", "mi", "ms", "iv", "bo", "ho", "bl"]},
	{"name": "Fortezza", "model": 4, "hull": 2, "eng": 1, "mt": 0, "bat": 2, "g": ["sh", "cm", "ra", "mi", "sn", "bo"]},
	{"name": "Sprinter", "model": 2, "hull": 0, "eng": 2, "mt": 2, "bat": 2, "g": ["bo", "ho", "bl", "sh", "cm"]},
	{"name": "Cecchino", "model": 3, "hull": 1, "eng": 0, "mt": 1, "bat": 2, "g": ["sn", "ms", "mi", "sh", "ra", "iv", "cm"]},
	{"name": "Ionico", "model": 1, "hull": 1, "eng": 1, "mt": 4, "bat": 1, "g": ["sn", "mi", "ms", "sh", "cm", "iv", "bo", "ho"]},
]

static func standard() -> Dictionary:
	return (PRESETS[0] as Dictionary).duplicate(true)

static func cost(c: Dictionary) -> int:
	var n: int = int(HULLS[_i(c, "hull", 1)][1]) + int(ENGINES[_i(c, "eng", 1)][1]) + int(BATTERIES[_i(c, "bat", 1)][1]) + int(MOTOR_TYPES[motor(c)][1])
	return n + _gadgets(c).size() * GADGET_COST

static func left(c: Dictionary) -> int:
	return CREDITS - cost(c)

static func _i(c: Dictionary, k: String, d: int) -> int:
	return clampi(int(c.get(k, d)), 0, 2)

static func motor(c: Dictionary) -> int:
	return clampi(int(c.get("mt", 0)), 0, MOTOR_TYPES.size() - 1)

static func _gadgets(c: Dictionary) -> Array:
	var out := []
	var g = c.get("g", [])
	if not g is Array:
		return out
	for k in SledGame.GADGET_ORDER:
		if g.has(k):
			out.append(k)
	return out

## Configurazione pulita e valida (dati da file o dalla rete): se sfora i crediti torna di serie.
static func sanitize(c) -> Dictionary:
	if not c is Dictionary or c.is_empty():
		return standard()
	var out := {
		"name": str(c.get("name", "Navetta")).strip_edges().substr(0, 24),
		"model": clampi(int(c.get("model", -1)), -1, MODELS.size() - 1),
		"hull": _i(c, "hull", 1), "eng": _i(c, "eng", 1), "bat": _i(c, "bat", 1), "mt": motor(c),
		"g": _gadgets(c),
	}
	if out["name"] == "":
		out["name"] = "Navetta"
	for k in ["id", "author", "saved_at", "gid"]:
		if c.has(k):
			out[k] = str(c[k])
	if cost(out) > CREDITS:
		return standard()
	return out

static func from_json(s: String) -> Dictionary:
	var d = JSON.parse_string(s) if s != "" else null
	return sanitize(d) if d is Dictionary else standard()

static func to_json(c: Dictionary) -> String:
	var d := sanitize(c)
	for k in ["id", "author", "saved_at", "gid"]:
		d.erase(k)
	return JSON.stringify(d)

## Mazzo di 20 carte dei motori scelti.
static func deck_counts(c: Dictionary) -> Array:
	return ENGINES[_i(c, "eng", 1)][2]

static func max_dents(c: Dictionary) -> int:
	return int(HULLS[_i(c, "hull", 1)][2])

static func curve_mod(c: Dictionary) -> int:
	return int(HULLS[_i(c, "hull", 1)][3])

static func hand_max(c: Dictionary) -> int:
	return int(HULLS[_i(c, "hull", 1)][4])

static func battery(c: Dictionary) -> int:
	return int(BATTERIES[_i(c, "bat", 1)][2])

## Riassunto in una riga.
static func summary(c: Dictionary) -> String:
	var g := _gadgets(c)
	return "Scafo %s · mazzo %s · motori %s · batteria %s · %d gadget" % [
		String(HULLS[_i(c, "hull", 1)][0]).to_lower(), String(ENGINES[_i(c, "eng", 1)][0]).to_lower(),
		String(MOTOR_TYPES[motor(c)][0]).to_lower(), String(BATTERIES[_i(c, "bat", 1)][0]).to_lower(), g.size()]

# ---------- salvataggi sul dispositivo ----------
const FILE := "user://navette.json"

static func load_local() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var out := []
	if d is Array:
		for x in d:
			if x is Dictionary:
				var c := sanitize(x)
				if not c.has("id"):
					c["id"] = new_id()
				out.append(c)
	return out

static func save_local(list: Array) -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list, " "))
		f.close()

## Salva (o aggiorna, se ha già un id) una navetta; restituisce la configurazione salvata.
static func store(c: Dictionary) -> Dictionary:
	var s := sanitize(c)
	if not s.has("id") or str(s["id"]) == "":
		s["id"] = new_id()
	s["saved_at"] = Time.get_datetime_string_from_system(true)
	var list := load_local()
	var done := false
	for i in list.size():
		if str(list[i].get("id", "")) == s["id"]:
			list[i] = s
			done = true
	if not done:
		list.append(s)
	save_local(list)
	return s

static func remove_local(id: String) -> void:
	var list := load_local().filter(func(x): return str(x.get("id", "")) != id)
	save_local(list)

static func new_id() -> String:
	var b := PackedByteArray()
	for i in 8:
		b.append(randi() % 256)
	return b.hex_encode()

# ---------- galleria online (Firebase, iontails/ships/<id>) ----------
const GALLERY := "iontails/ships"

## Pubblica la navetta nella galleria: {ok, error}.
static func publish(net: Net, c: Dictionary, author: String) -> Dictionary:
	if not await net.sign_in():
		return {"ok": false, "error": net.last_error}
	var s := sanitize(c)
	var id := str(s.get("gid", ""))
	if id == "":
		id = new_id()
	var body := {"uid": net.uid, "name": s["name"], "author": author.substr(0, 24), "cfg": to_json(s),
		"ts": int(Time.get_unix_time_from_system())}
	var r := await net.db_put("%s/%s" % [GALLERY, id], body)
	if int(r["code"]) != 200:
		return {"ok": false, "error": "risposta %d %s" % [int(r["code"]), net.last_error]}
	return {"ok": true, "id": id}

## Le navette della galleria, dalla più recente: [{id, name, author, cfg, mine}].
static func gallery(net: Net) -> Dictionary:
	if not await net.sign_in():
		return {"ok": false, "error": net.last_error, "list": []}
	var r := await net.db_get(GALLERY)
	if int(r["code"]) != 200:
		return {"ok": false, "error": "risposta %d" % int(r["code"]), "list": []}
	var data := Net._as_dict(r["data"])
	var list := []
	for id in data:
		var e = data[id]
		if not e is Dictionary:
			continue
		var c := from_json(str(e.get("cfg", "")))
		c["name"] = str(e.get("name", c["name"])).substr(0, 24)
		list.append({"id": str(id), "name": c["name"], "author": str(e.get("author", "")), "cfg": c,
			"ts": int(e.get("ts", 0)), "mine": str(e.get("uid", "")) == net.uid})
	list.sort_custom(func(a, b): return int(a["ts"]) > int(b["ts"]))
	return {"ok": true, "list": list}

static func unpublish(net: Net, id: String) -> bool:
	if not await net.sign_in():
		return false
	var r := await net.db_delete("%s/%s" % [GALLERY, id])
	return int(r["code"]) == 200
