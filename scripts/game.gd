class_name SledGame
extends RefCounted
## Regole di gioco: mazzi, navette, movimento, danni, ordine, CPU.

const NAMES := ["Rosso", "Blu", "Giallo", "Verde", "Viola"]
const COLORS := [Color("cf3a30"), Color("2a9ac0"), Color("e0b020"), Color("5a9e2f"), Color("9a5fe0")]
const SLOTN := {"L": "motore sx", "R": "motore dx", "B": "freno"}

class Player:
	var id := 0
	var seat := 0          # colore/posto scelto nel menu (indice in NAMES e COLORS)
	var name := ""
	var color := Color.WHITE
	var ai := false
	var deck: Array = []
	var hand: Array = []
	var discard: Array = []
	var used: Array = []
	var L := 3
	var R := 3
	var B := 3
	var lc := false
	var rc := false
	var dents := 0
	var half := false          # mezzo danno (variante simultanea): due mezze fanno una intera
	var cell := -1
	var wrecked := false
	var moves := 0
	var slot := -1
	var stalls := 0
	var finish_round := 0      # giro in cui ha tagliato il traguardo (0 = non ancora)
	var smart := true          # CPU che guarda avanti le caratteristiche fanmade (false = la vecchia, per i confronti)
	# --- Ion Tails: energia e gadget ---
	var energy := 0            # punti gadget rimasti
	var al := {}               # punti investiti nel turno: chiave di GADGETS -> livello; "snt" = bersaglio del cecchino
	var drag := 0              # rallentamento da arpione in questo turno
	var spent := 0             # punti spesi in tutta la gara (statistica)

var course: Course
var players: Array = []
var round_n := 1
var order: Array = []
var oi := 0
var log_text := ""
var over := false
var results: Array = []
var saplings := {}          # massi ancora in pista
# registrazione per il replay: history[giro-1] = [{pid, path: [partenza, ...], dents, wrecked, sap}]
var history: Array = []
var start_record := {}
var initial_saplings := {}
## Sabbia ancora intatta: la prima navetta che ci passa la spazza via (come gli massi)
var fresh := {}
var initial_fresh := {}
var last_fx := {}
var last_snow := []         # sabbia spazzata dall'ultima mossa, per il replay           # effetti dell'ultima mossa, per il replay
## Generatore casuale della partita: tutti i mescolamenti passano da qui. Online ogni dispositivo
## parte dallo stesso seme, quindi i mazzi restano identici ovunque senza doverli trasmettere.
var rng := RandomNumberGenerator.new()
## Variante: tutti programmano la mossa, poi le navette si muovono insieme.
## Le rotte si calcolano senza tener conto delle altre navette; i conflitti si risolvono dopo.
var simultaneous := false

# ---------- Ion Tails: punti gadget ----------
## Regole aggiuntive: a inizio gara ogni navetta riceve una scorta di punti in base alla
## lunghezza della pista (BUDGET_DIV passi per punto). A ogni turno ognuno decide in segreto
## quanti punti investire (da 0 a MAX_LEVEL) in attacchi, difese e movimento.
var energy_on := true
const BUDGET_DIV := 5.0
const MAX_LEVEL := 3
## chiave -> [nome, categoria, descrizione per livello]
const GADGETS := {
	"sn": ["Cecchino", "Attacchi", "spara alla navetta scelta quando finisce la mossa: più punti, più precisione; sbaglia più spesso se il bersaglio va veloce o sta lontano dalle pareti"],
	"mi": ["Mine", "Attacchi", "una mina per punto, sulle caselle che ti lasci dietro: chi ci passa prende 1 danno"],
	"ms": ["Missile", "Attacchi", "a fine mossa spara dritto davanti nella tua corsia; gittata 3 caselle più 2 per punto"],
	"sh": ["Scudo", "Difese", "ogni punto toglie il 30% alla mira dei cecchini, ma solo il 15% ai missili che arrivano da dietro"],
	"ra": ["Radar", "Difese", "rivela le mine del settore in cui sei (1 punto), anche del seguente (2), dei due seguenti (3)"],
	"cm": ["CME", "Difese", "contromisure: con 1 punto il missile cambia corsia una volta su due, con 2 cambia sempre corsia, con 3 esplode"],
	"bo": ["Postbruciatore", "Movimento", "+1 velocità per punto in questa mossa (conta anche per i limiti delle curve)"],
	"ho": ["Arpione", "Movimento", "la navetta più vicina davanti a te (fino a 6 passi) ha −1 velocità per punto in questo turno"],
	"bl": ["Blast ionico", "Movimento", "a fine mossa spinge di lato la navetta più vicina davanti (fino a 3 passi) di una corsia per punto, verso il bordo"],
}
const GADGET_ORDER := ["sn", "mi", "ms", "sh", "ra", "cm", "bo", "ho", "bl"]
const CATEGORIES := ["Attacchi", "Difese", "Movimento"]
var mines := {}            # casella -> id della navetta che l'ha sganciata
var smoke := {}            # (non più usato: resta per compatibilità con l'interfaccia)
var budget := 0            # punti gadget di ogni navetta a inizio gara

## Mescola un elenco con il generatore della partita (al posto di Array.shuffle, che usa quello globale).
func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## seed_value 0 = partita qualunque; online tutti usano il seme scelto da chi ha creato la stanza.
func setup(c: Course, ai_flags: Array, seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	course = c
	players.clear()
	# ai_flags: un valore per colore; -1 (o null) = colore non in gara
	for i in ai_flags.size():
		var f = ai_flags[i]
		if f == null or (typeof(f) != TYPE_BOOL and int(f) < 0):
			continue
		var p := Player.new()
		p.id = players.size()
		p.seat = i
		p.name = NAMES[i]
		p.color = COLORS[i]
		p.ai = bool(f)
		p.deck = make_deck()
		players.append(p)
	round_n = 1
	over = false
	results = []
	order = []
	saplings = {}
	for id in c.saplings:
		saplings[id] = true
	initial_saplings = saplings.duplicate()
	fresh = c.fresh.duplicate()
	initial_fresh = fresh.duplicate()
	history = []
	start_record = {}
	oi = 0
	mines = {}
	smoke = {}
	budget = budget_for(c)
	for p in players:
		p.energy = budget

func make_deck() -> Array:
	var d := []
	for v in range(1, 6):
		for k in 4:
			d.append(v)
	shuffle(d)
	return d

func cell(id: int) -> Dictionary:
	return course.cells[id]

func hand_size(p: Player) -> int:
	return p.hand.size() + p.dents

# ---------- partenza ----------
func free_slots() -> Array:
	var out := []
	for k in 5:
		var taken := false
		for p in players:
			if p.slot == k:
				taken = true
		if not taken:
			out.append(k)
	return out

func take_slot(p: Player, k: int) -> void:
	p.slot = k
	p.cell = course.start_cells[k]

func deal_all() -> void:
	for p in players:
		start_record[p.id] = p.cell
	for p in players:
		var n := 5
		if p.slot == 3: n = 6
		if p.slot == 4: n = 7
		for k in n:
			p.hand.append(p.deck.pop_back())
		p.hand.sort()

# ---------- ordine di gara ----------
func prog_key(p: Player) -> float:
	var c := cell(p.cell)
	var nc := course.next_corner(c["piece"])
	var side: float = clamp(float(c["lat"]) / course.lane_w, -2.5, 2.5)
	var tb := 2.5 - side          # verso sinistra = interno
	if not nc.is_empty() and nc["turn"] == "R":
		tb = 2.5 + side
	return floor(float(c["s"]) / (course.cell_len * 0.3)) * 10.0 + tb

func race_order() -> Array:
	var arr := []
	for p in players:
		if not p.wrecked and p.cell >= 0:
			arr.append(p)
	arr.sort_custom(func(a, b): return prog_key(a) > prog_key(b))
	return arr

func rank_of(p: Player) -> int:
	return race_order().find(p) + 1

func is_finished(p: Player) -> bool:
	return not p.wrecked and p.cell >= 0 and int(cell(p.cell)["piece"]) >= course.finish_piece

# ---------- carte ----------
func add_dent(p: Player, n: int) -> void:
	for i in n:
		if p.dents >= 4:
			if is_finished(p):
				continue
			p.wrecked = true
			p.cell = -1
			return
		p.dents += 1

## Mezzo danno: la seconda mezza diventa un danno intera.
func add_half_dent(p: Player) -> void:
	if p.half:
		p.half = false
		add_dent(p, 1)
	else:
		p.half = true

func draw_up(p: Player) -> void:
	while hand_size(p) < 5:
		if p.deck.is_empty():
			p.deck = p.discard + p.used
			p.discard = []
			p.used = []
			shuffle(p.deck)
			if p.deck.is_empty():
				break
		p.hand.append(p.deck.pop_back())
	p.hand.sort()

func mat_after(p: Player, pend: Array) -> Dictionary:
	var m := {"L": p.L, "R": p.R, "B": p.B}
	for x in pend:
		m[x["slot"]] = x["v"]
	var xs := speed_extra(p)
	if xs != 0:
		m["X"] = xs
	return m

func commit_play(p: Player, pend: Array) -> void:
	for x in pend:
		var v: int = x["v"]
		p.hand.erase(v)
		match String(x["slot"]):
			"L":
				if p.lc: p.used.append(p.L)
				p.L = v
				p.lc = true
			"R":
				if p.rc: p.used.append(p.R)
				p.R = v
				p.rc = true
			_:
				p.discard.append(v)
				p.B = v

# ---------- movimento ----------
## Tutti gli esiti possibili del movimento: ogni passo è "avanti" (oltre una linea blu)
## o "deriva" (avanti in diagonale oltre una linea nera); dove la rete offre più
## caselle si esplorano tutte. Gli esiti sono raggruppati per casella d'arrivo.
## Segmenti fanmade: chi parte in salita perde UP_LOSS punti di velocità (come un freno in più);
## chi parte in discesa guadagna 1 punto ogni DOWN_PER (3 → 4, 6 → 8, 9 → 12); la sabbia
## costa 2 punti per casella; sul vetro chi
## entra derivando continua a derivare e a fine movimento scivola avanti di una casella;
## il vento sposta di una corsia ogni 2 caselle percorse; l'officina ripara un danno.
const UP_LOSS := 3
const DOWN_PER := 3

## Motori − retrorazzi, più gadget (postbruciatore, arpione), scia ionica e rallentamento da
## arpione (chiave "X" della plancia). Chi frena fino a fermarsi resta fermo.
func base_speed(m: Dictionary) -> int:
	var sp: int = m["L"] + m["R"] - m["B"]
	if sp > 0:
		sp = max(sp + int(m.get("X", 0)), 0)
	return sp

## Velocità con la plancia m partendo dalla casella cell: motori − retrorazzi, poi la pendenza.
func effective_speed(cell_id: int, m: Dictionary) -> int:
	var speed: int = base_speed(m)
	match course.slope_of(cell_id) if cell_id >= 0 else "":
		"up":
			speed -= UP_LOSS
		"down":
			if speed > 0:
				speed += speed / DOWN_PER
	if cell_id >= 0:
		speed += course.wind_speed_of(cell_id)
	return max(speed, 0)

## Deriva con la plancia m partendo dalla casella cell: motore destro − motore sinistro, più il vento
## della tessera (WIND_PUSH corsie nel suo verso). Positiva = a destra.
const WIND_PUSH := 1
func effective_drift(cell_id: int, m: Dictionary) -> int:
	var d: int = m["R"] - m["L"]
	if cell_id >= 0:
		d += course.wind_of(cell_id) * WIND_PUSH
	return d

func compute_outs(p: Player, m: Dictionary, all_paths := false) -> Array:
	var base: int = max(base_speed(m), 0)
	var speed: int = effective_speed(p.cell, m)
	var drift: int = effective_drift(p.cell, m)
	var wind_d: int = drift - (m["R"] - m["L"])
	var slope_delta: int = speed - base
	if speed <= 0:
		return [{"path": [], "end": p.cell, "dents": 0, "corner_dents": 0, "crash": "", "bonus": false, "bonus_n": 0, "speed": 0, "sap": []}]
	var dir := signi(drift)
	var k: int = min(abs(drift), speed)
	var occ := {}
	for q in ([] if simultaneous else players):
		# le navette già arrivate restano parcheggiate oltre la linea ma non ostacolano chi arriva dopo
		if q != p and not q.wrecked and q.cell >= 0 and q.finish_round == 0:
			occ[q.cell] = true
	var res := []
	var up0: bool = course.slope_of(p.cell) == "up"
	_dfs(p.cell, speed, k, dir, speed, occ, [], 0, res, 0, [], up0, "")
	if drift == 0 and m["L"] == m["R"] and p.moves > 0:
		var b := rank_of(p)
		_dfs(p.cell, speed + b, 0, 0, speed + b, occ, [], 0, res, b, [], up0, "")
	for r in res:
		r["from"] = p.cell
		_post_move(r, occ)
		if slope_delta != 0:
			r["slope"] = slope_delta
		if wind_d != 0:
			r["wind"] = wind_d
		if course.wind_speed_of(p.cell) != 0:
			r["wind_speed"] = course.wind_speed_of(p.cell)
	# mine viste col radar: la rotta le evita quando può (e la CPU ne tiene conto)
	if int(p.al.get("ra", 0)) > 0:
		for r in res:
			var km := 0
			for t in r["path"]:
				if sees_mine(p, int(t)) and int(mines[t]) != p.id:
					km += 1
			r["km"] = km
	if all_paths:
		return res
	var best := {}
	for r in res:
		var sc: float = (r["dents"] + int(r.get("km", 0))) * 10.0 + (3.0 if r["crash"] == "sled" else 0.0) + (0.5 if r["bonus"] else 0.0)
		r["_sc"] = sc
		if not best.has(r["end"]) or sc < best[r["end"]]["_sc"]:
			best[r["end"]] = r
	return best.values()

func _out(path: Array, end: int, crash: String, cd: int, total: int, bonus_n: int, sap: Array) -> Dictionary:
	return {"path": path, "end": end, "crash": crash, "corner_dents": cd, "sap": sap,
		"dents": cd + sap.size() + (1 if crash == "edge" else 0), "bonus": bonus_n > 0, "bonus_n": bonus_n, "speed": total}

func _dfs(cur: int, steps: int, drifts: int, dir: int, total: int, occ: Dictionary, path: Array, cd: int, res: Array, bonus_n: int, sap: Array, up := false, last := "") -> void:
	if res.size() > 20000:
		return
	if steps == 0:
		res.append(_out(path, cur, "", cd, total, bonus_n, sap))
		return
	var c := cell(cur)
	var kinds := []
	if course.has_mod(cur, "ice") and last == "d" and drifts > 0:
		# sul vetro la deriva non si ferma: chi ci entra derivando continua a derivare
		kinds = ["d"]
	else:
		if drifts < steps:
			kinds.append("f")
		if drifts > 0:
			kinds.append("d")
	for kind in kinds:
		var targets: Array = c["fwd"] if kind == "f" else (c["dr"] if dir > 0 else c["dl"])
		var nd: int = drifts - (1 if kind == "d" else 0)
		if targets.is_empty():
			var crash := "end" if (kind == "f" and course.is_last_piece(c["piece"])) else "edge"
			var r := _out(path, cur, crash, cd, total, bonus_n, sap)
			var hv := course.heading(cur)
			if kind == "d":
				hv = (hv + Vector2(-hv.y, hv.x) * float(dir)).normalized()
			r["hit_dir"] = hv
			res.append(r)
			continue
		for t in targets:
			if occ.has(t):
				var r2 := _out(path, cur, "sled", cd, total, bonus_n, sap)
				r2["hit_dir"] = (cell(t)["pos"] - c["pos"]).normalized()
				r2["hit_cell"] = t
				res.append(r2)
				continue
			var cost := 2 if fresh.has(t) else 1
			var up2: bool = up or course.slope_of(t) == "up"
			if cost > steps:
				# non ci entra: sabbia troppo profonda per i punti rimasti
				var r3 := _out(path, cur, "", cd, total, bonus_n, sap)
				r3["stopped"] = "fresh"
				res.append(r3)
				continue
			var cd2: int = cd + course.limit_dents(c["piece"], cell(t)["piece"], total) + course.leap_dents(cur, t, total)
			var p2 := path.duplicate()
			p2.append(t)
			var s2 := sap
			if saplings.has(t):
				s2 = sap.duplicate()
				s2.append(t)
			_dfs(t, steps - cost, nd if cost == 1 else min(nd, steps - cost), dir, total, occ, p2, cd2, res, bonus_n, s2, up2, kind)

## Variante simultanea: dalle mosse programmate (pid -> {pend, o}) ricava gli esiti reali.
## Le navette si muovono insieme per tutta la durata del giro: chi ha n caselle da fare entra
## nella casella k al tempo k/n. Due navette non possono stare nella stessa casella nello stesso
## momento. Si decide in quest'ordine: prima chi resta ferma (non può spostarsi), poi chi va più
## veloce, a parità chi era più avanti a inizio giro. Ognuna, se può, sceglie fra le rotte
## equivalenti (stessa casella d'arrivo, stessa velocità, non più danni) una che non tocca
## nessuno; se non c'è, si ferma prima del contatto e prende mezzo danno.
## Gli massi li travolge chi ci passa per primo.
func resolve_simultaneous(progs: Dictionary) -> Array:
	var list := []
	for p in race_order():
		if racing(p) and progs.has(p.id):
			list.append(p)
	var rank := {}
	for i in list.size():
		rank[list[i].id] = i
	var cands := {}
	for p in list:
		var o0: Dictionary = progs[p.id]["o"]
		var lst := [o0]
		if not (o0["path"] as Array).is_empty():
			var m := mat_after(p, progs[p.id]["pend"])
			for o in compute_outs(p, m, true):
				if lst.size() >= 60:
					break
				if int(o["end"]) == int(o0["end"]) and int(o["speed"]) == int(o0["speed"]) and o["bonus"] == o0["bonus"] \
						and int(o["dents"]) <= int(o0["dents"]) and str(o["path"]) != str(o0["path"]) and String(o["crash"]) == String(o0["crash"]):
					lst.append(o)
		cands[p.id] = lst
	var prio := list.duplicate()
	prio.sort_custom(func(a, b):
		var sa: int = 1000 if (progs[a.id]["o"]["path"] as Array).is_empty() else int(progs[a.id]["o"]["speed"])
		var sb: int = 1000 if (progs[b.id]["o"]["path"] as Array).is_empty() else int(progs[b.id]["o"]["speed"])
		if sa != sb:
			return sa > sb
		return rank[a.id] < rank[b.id])
	var fixed := []          # [{cell, a, b, pid}]
	var done := {}
	for p in prio:
		var lst: Array = cands[p.id]
		var o0: Dictionary = lst[0]
		var n: int = max((o0["path"] as Array).size(), 1)
		var best = null
		var best_sc := INF
		for i in lst.size():
			var o: Dictionary = lst[i]
			var tl := _timeline(p.id, [p.cell] + o["path"], n, (o["path"] as Array).size())
			if _clash(tl, fixed) >= 0:
				continue
			# a parità, meglio non intralciare le rotte di chi deve ancora decidere
			var sc := 0.0 if i == 0 else 0.25
			for q in prio:
				if q != p and not done.has(q.id):
					var qo: Dictionary = progs[q.id]["o"]
					var qn: int = max((qo["path"] as Array).size(), 1)
					if _clash(_timeline(q.id, [q.cell] + qo["path"], qn, (qo["path"] as Array).size()), tl) >= 0:
						sc += 1.0
			if sc < best_sc:
				best_sc = sc
				best = o
		var o_use: Dictionary
		var half := false
		var yield_pid := -1
		var hit := -1
		if best != null:
			o_use = (best as Dictionary).duplicate(true)
		else:
			o_use = o0.duplicate(true)
			var full: Array = [p.cell] + o_use["path"]
			var k: int = full.size() - 1
			while k > 0:
				var c := _clash(_timeline(p.id, full, n, k), fixed)
				if c < 0:
					break
				if k == full.size() - 1 or yield_pid < 0:
					yield_pid = int(fixed[c]["pid"])
				k -= 1
			hit = full[k + 1] if k + 1 < full.size() else -1
			o_use["path"] = full.slice(1, k + 1)
			half = true
		var path: Array = o_use["path"]
		var total := int(o_use["speed"])
		var cd := 0
		var prev: int = p.cell
		for t in path:
			cd += course.limit_dents(cell(prev)["piece"], cell(t)["piece"], total) + course.leap_dents(prev, t, total)
			prev = t
		o_use["end"] = p.cell if path.is_empty() else path[path.size() - 1]
		o_use["from"] = p.cell
		o_use["corner_dents"] = cd
		o_use["half"] = half
		o_use["n"] = n
		if half:
			o_use["crash"] = "bump"
			if hit >= 0:
				o_use["hit_cell"] = hit
				o_use["hit_dir"] = (cell(hit)["pos"] - cell(o_use["end"])["pos"]).normalized()
			if yield_pid >= 0:
				o_use["yield_to"] = players[yield_pid].name
		fixed.append_array(_timeline(p.id, [p.cell] + path, n, path.size()))
		done[p.id] = {"p": p, "pend": progs[p.id]["pend"], "o": o_use, "start": p.cell, "n": n}
	# massi: li prende chi ci arriva per primo
	var first := {}
	for pid in done:
		var x: Dictionary = done[pid]
		var pth: Array = x["o"]["path"]
		for k in pth.size():
			var t: int = pth[k]
			if saplings.has(t):
				var tm: float = float(k + 1) / float(x["n"])
				if not first.has(t) or tm < first[t][0] or (tm == first[t][0] and rank[pid] < rank[first[t][1]]):
					first[t] = [tm, pid]
	var plan := []
	for p in list:
		var x: Dictionary = done[p.id]
		var o: Dictionary = x["o"]
		var sap := []
		for t in o["path"]:
			if first.has(t) and int(first[t][1]) == p.id:
				sap.append(t)
		o["sap"] = sap
		o["dents"] = int(o["corner_dents"]) + sap.size() + (1 if String(o["crash"]) == "edge" else 0)
		plan.append(x)
	return plan

## Occupazione nel tempo (giro da 0 a 1): la navetta entra nella casella k di full al tempo k/n
## e la lascia quando entra nella successiva; nell'ultima casella raggiunta (stop) resta per sempre.
## La casella di partenza si libera subito, tranne per chi non si muove.
func _timeline(pid: int, full: Array, n: int, stop: int) -> Array:
	var tl := []
	if stop <= 0:
		tl.append({"cell": full[0], "a": 0.0, "b": INF, "pid": pid})
		return tl
	for k in range(1, stop + 1):
		var a := float(k) / float(n)
		var b: float = INF if k == stop else float(k + 1) / float(n)
		tl.append({"cell": full[k], "a": a, "b": b, "pid": pid})
	return tl

## Indice in other del primo intervallo che si sovrappone a tl (stessa casella, stesso momento), o -1.
func _clash(tl: Array, other: Array) -> int:
	for x in tl:
		for i in other.size():
			var y: Dictionary = other[i]
			if int(y["cell"]) == int(x["cell"]) and max(float(x["a"]), float(y["a"])) < min(float(x["b"]), float(y["b"])) - 0.000001:
				return i
	return -1

## Dopo il movimento scelto: scivolata sul vetro e spinta del vento.
func _post_move(r: Dictionary, occ: Dictionary) -> void:
	if String(r["crash"]) != "":
		return
	var path: Array = (r["path"] as Array).duplicate()
	if path.is_empty():
		return
	var end: int = r["end"]
	var sap: Array = (r["sap"] as Array).duplicate()
	# vetro: a fine movimento si scivola avanti di una casella
	if course.has_mod(end, "ice"):
		var fw: Array = cell(end)["fwd"]
		if not fw.is_empty():
			var h := course.heading(end)
			var t: int = fw[0]
			for f in fw:
				if (cell(f)["pos"] - cell(end)["pos"]).normalized().dot(h) > (cell(t)["pos"] - cell(end)["pos"]).normalized().dot(h):
					t = f
			if occ.has(t):
				r["crash"] = "sled"
				r["hit_cell"] = t
				r["hit_dir"] = (cell(t)["pos"] - cell(end)["pos"]).normalized()
			else:
				path.append(t)
				end = t
				r["ice"] = true
				if saplings.has(t) and not sap.has(t):
					sap.append(t)
	r["path"] = path
	r["end"] = end
	r["sap"] = sap
	r["dents"] = int(r["corner_dents"]) + sap.size() + (1 if String(r["crash"]) == "edge" else 0)

func describe(pend: Array, o: Dictionary, m: Dictionary) -> String:
	var v: int = pend[0]["v"]
	var where := []
	for x in pend:
		where.append(SLOTN[x["slot"]])
	var s := ""
	if pend.size() > 1:
		s = "%d carte da %d su %s" % [pend.size(), v, " e ".join(where)]
	else:
		s = "una carta da %d su %s" % [v, where[0]]
	s += ", velocità %d" % o["speed"]
	if o["bonus"]:
		s += " (bonus +%d)" % o["bonus_n"]
	var d: int = m["R"] - m["L"]
	if d != 0:
		s += ", deriva %d a %s" % [abs(d), "destra" if d > 0 else "sinistra"]
	return s

## Dopo il movimento. Restituisce true se un umano deve scartare carte.
func after_move(p: Player, o: Dictionary) -> bool:
	p.moves += 1
	p.stalls = p.stalls + 1 if (o["path"] as Array).is_empty() else 0
	var msgs := []
	var corner_only: int = int(o["corner_dents"]) - _leap_part(o)
	if corner_only > 0:
		msgs.append("curva presa troppo forte (+%d)" % corner_only)
	if _leap_part(o) > 0:
		msgs.append("salto troppo lento (+%d)" % _leap_part(o))
	var in_crev: bool = course.crevasse.has(int(o["end"]))
	var sd := int(o.get("slope", 0))
	if sd < 0:
		msgs.append("la salita la rallenta (%d)" % sd)
	elif sd > 0:
		msgs.append("in discesa prende velocità (+%d)" % sd)
	match String(o.get("stopped", "")):
		"fresh":
			msgs.append("si pianta nella sabbia")
	if o.get("ice", false):
		msgs.append("scivola sul vetro")
	if int(o.get("wind", 0)) != 0:
		msgs.append("la tempesta di sabbia la spinge %s (%d)" % ["a destra" if int(o["wind"]) > 0 else "a sinistra", abs(int(o["wind"]))])
	if int(o.get("wind_speed", 0)) != 0:
		msgs.append("tempesta %s (%+d)" % ["a favore" if int(o["wind_speed"]) > 0 else "contraria", int(o["wind_speed"])])
	if in_crev:
		msgs.append("si ferma nella spaccatura e non pesca")
	var swept := []
	for t in o["path"]:
		if fresh.has(t):
			swept.append(t)
			fresh.erase(t)
	if swept.size() > 0:
		msgs.append("spazza via la sabbia")
	o["snow"] = swept
	last_snow = swept.duplicate()
	var sap: Array = o.get("sap", [])
	if sap.size() > 0:
		msgs.append("travolge %s (+%d)" % ["un masso" if sap.size() == 1 else "%d massi" % sap.size(), sap.size()])
		for t in sap:
			saplings.erase(t)
	if energy_on:
		_gadgets_after_move(p, o, msgs)
	if o["crash"] == "edge":
		msgs.append("urta il bordo (+1)")
	if o["crash"] == "sled":
		msgs.append("tampona e non pesca")
	if o.get("half", false):
		msgs.append("frena per non urtare %s (+½)" % String(o.get("yield_to", "un'altra navetta")))
	if o["dents"] > 0:
		add_dent(p, o["dents"])
	if o.get("half", false) and not p.wrecked:
		add_half_dent(p)
	if p.wrecked:
		msgs.append("la navetta va in pezzi!")
	elif is_finished(p) and p.finish_round == 0:
		p.finish_round = round_n
		var n := 0
		for q in players:
			if q.finish_round > 0: n += 1
		msgs.append("taglia il traguardo! (%d° ad arrivare)" % n)
	if not msgs.is_empty():
		log_text += " — " + "; ".join(msgs)
	if p.wrecked:
		return false
	# officina: chi ci si ferma ripara metà dei danni (arrotondando a suo favore), ma non pesca
	var repaired := false
	if course.huts.has(int(o["end"])) and String(o["crash"]) == "" and (p.dents > 0 or p.half):
		var units := p.dents * 2 + (1 if p.half else 0)      # in mezzi danni
		var left := units / 2
		p.dents = left / 2
		p.half = left % 2 == 1
		repaired = true
		log_text += " — si ripara all'officina (metà dei danni, non pesca)"
	if o["crash"] != "sled" and not in_crev and not repaired:
		draw_up(p)
	if hand_size(p) > 5 and not p.hand.is_empty():
		if p.ai:
			ai_discard(p)
		else:
			return true
	return false

## Parte deli danni dovuta al salto (calcolata lungo il percorso dell'esito).
func _leap_part(o: Dictionary) -> int:
	var d := 0
	var prev: int = o.get("from", -1)
	for t in o["path"]:
		if prev >= 0:
			d += course.leap_dents(prev, t, int(o["speed"]))
		prev = t
	return d

## Registra la mossa appena fatta (chiamata dopo after_move).
func record(p: Player, start_cell: int, path: Array, sap: Array) -> void:
	while history.size() < round_n:
		history.append([])
	var full := [start_cell]
	full.append_array(path)
	history[round_n - 1].append({"pid": p.id, "path": full, "dents": p.dents, "wrecked": p.wrecked,
		"end": p.cell, "sap": sap.duplicate(), "snow": last_snow.duplicate(), "fx": last_fx.duplicate()})
	last_snow = []
	last_fx = {}

## Una navetta ancora in corsa: non distrutta e non ancora oltre il traguardo.
func racing(p: Player) -> bool:
	return not p.wrecked and p.finish_round == 0

## La gara finisce quando tutte le navette rimaste hanno tagliato il traguardo.
func check_round_end() -> bool:
	var left := 0
	for p in players:
		if racing(p):
			left += 1
	if left == 0 or round_n >= 100:
		_game_over()
		return true
	round_n += 1
	return false

func _game_over() -> void:
	over = true
	var fin := []
	var notf := []
	var wr := []
	for p in players:
		if p.wrecked: wr.append(p)
		elif is_finished(p): fin.append(p)
		else: notf.append(p)
	var by_key := func(a, b): return prog_key(a) > prog_key(b)
	# prima chi ha tagliato il traguardo in un giro precedente, poi chi è più lontano oltre la linea
	fin.sort_custom(func(a, b):
		if a.finish_round != b.finish_round:
			return a.finish_round < b.finish_round
		return prog_key(a) > prog_key(b))
	notf.sort_custom(by_key)
	results = []
	for p in fin:
		var past := int(floor((float(cell(p.cell)["s"]) - course.finish_s) / course.cell_len)) + 1
		results.append({"p": p, "st": "arrivata al turno %d, %d oltre il traguardo" % [p.finish_round, max(past, 0)]})
	for p in notf:
		results.append({"p": p, "st": "ancora in gara"})
	for p in wr:
		results.append({"p": p, "st": "distrutta"})

# ---------- CPU ----------
func ai_choose(p: Player) -> Dictionary:
	var cands := _ai_candidates(p)
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b): return a["sc"] > b["sc"])
	if not p.smart or not ai_parts.get("ply2", true):
		return cands[0]
	# sguardo al turno dopo: per le mosse migliori si simula anche la mossa seguente con le
	# carte che restano in mano. Così salite, discese, vento e vetro si valutano davvero.
	var best: Dictionary = cands[0]
	var best_sc := -INF
	for i in min(AI_TOP, cands.size()):
		var c: Dictionary = cands[i]
		var sc: float = c["sc"] + AI_PLY2 * _ai_next_turn(p, c)
		if sc > best_sc:
			best_sc = sc
			best = c
	return best

const AI_TOP := 6
const AI_PLY2 := 0.6

func _ai_candidates(p: Player) -> Array:
	var counts := {}
	for v in p.hand:
		counts[v] = counts.get(v, 0) + 1
	var subs := [["L"], ["R"], ["B"], ["L", "R"], ["L", "B"], ["R", "B"], ["L", "R", "B"]]
	var out := []
	for v in counts.keys():
		for sub in subs:
			if sub.size() > counts[v]:
				continue
			var pend := []
			for s in sub:
				pend.append({"v": v, "slot": s})
			var m := mat_after(p, pend)
			for o in compute_outs(p, m):
				out.append({"sc": ai_score(p, m, o, pend.size()), "pend": pend, "o": o, "m": m})
	return out

## Miglior avanzamento del turno dopo, partendo dall'esito c, con le carte rimaste in mano.
func _ai_next_turn(p: Player, c: Dictionary) -> float:
	var o: Dictionary = c["o"]
	if int(cell(o["end"])["piece"]) >= course.finish_piece:
		return 30.0
	var save := {"cell": p.cell, "L": p.L, "R": p.R, "B": p.B, "hand": p.hand.duplicate(), "moves": p.moves, "dents": p.dents}
	p.cell = o["end"]
	p.L = c["m"]["L"]
	p.R = c["m"]["R"]
	p.B = c["m"]["B"]
	for x in c["pend"]:
		p.hand.erase(x["v"])
	p.moves += 1
	p.dents += int(o["dents"])
	var best := -60.0
	var counts := {}
	for v in p.hand:
		counts[v] = counts.get(v, 0) + 1
	var subs := [["L"], ["R"], ["B"], ["L", "R"]]
	var from_togo := int(cell(p.cell)["togo"])
	for v in counts.keys():
		for sub in subs:
			if sub.size() > counts[v]:
				continue
			var pend := []
			for s2 in sub:
				pend.append({"v": v, "slot": s2})
			for o2 in compute_outs(p, mat_after(p, pend)):
				var sc := float(from_togo - int(cell(o2["end"])["togo"])) * 10.0
				sc -= float(o2["dents"]) * (22.0 + p.dents * 14.0)
				if p.dents + int(o2["dents"]) >= 5:
					sc -= 300.0
				if sc > best:
					best = sc
	p.cell = save["cell"]
	p.L = save["L"]
	p.R = save["R"]
	p.B = save["B"]
	p.hand = save["hand"]
	p.moves = save["moves"]
	p.dents = save["dents"]
	return best if best > -60.0 else 0.0

func ai_score(p: Player, m: Dictionary, o: Dictionary, n_cards: int) -> float:
	var st := cell(p.cell)
	var en := cell(o["end"])
	var cl := course.cell_len
	# avanzamento misurato in passi che mancano al traguardo: tiene conto
	# dei vicoli ciechi (crepacci, cumuli, strisce esterne delle curve)
	var s: float = float(int(st["togo"]) - int(en["togo"])) * 10.0
	var fin: bool = int(en["piece"]) >= course.finish_piece
	if fin:
		# oltre il traguardo conta andare il più lontano possibile (spareggio nello stesso giro)
		s += 300.0 + (float(en["s"]) - course.finish_s) / cl * 25.0
	if p.dents + int(o["dents"]) >= 5 and not fin:
		return -500.0 + s
	s -= float(o["dents"] + int(o.get("km", 0))) * (22.0 + p.dents * 14.0)
	if o["crash"] == "sled" or course.crevasse.has(int(o["end"])):
		s -= 14.0
	var S2: int = m["L"] + m["R"] - m["B"]
	var d2: int = m["R"] - m["L"]
	if p.smart and not fin:
		s += _ai_lookahead(p, o, S2, d2)
		# dalla pendenza si riparte più veloci o più lenti: lo sa per le curve e i salti che vengono dopo
		if ai_parts["down"]:
			S2 = effective_speed(int(o["end"]), m)
	if S2 <= 1:
		s -= 10.0
	var nl := course.next_limit(float(en["s"]))
	if not nl.is_empty():
		var dist: float = (float(nl["s"]) - float(en["s"])) / cl
		if S2 > int(nl["lim"]) and dist <= S2 + 2:
			s -= (S2 - int(nl["lim"])) * (14.0 if dist <= S2 else 6.0)
	var lp := course.next_leap(float(en["s"]))
	if not lp.is_empty():
		var dl: float = (float(lp["s"]) - float(en["s"])) / cl
		if dl <= S2 + 1 and S2 < int(lp["min"]):
			s -= (int(lp["min"]) - S2) * 10.0
	if not fin:
		var steps: int = max(S2, 0)
		var k: int = min(abs(d2), steps)
		var cc: int = o["end"]
		for i in k:
			var opts: Array = cell(cc)["dr"] if d2 > 0 else cell(cc)["dl"]
			if opts.is_empty():
				s -= 18.0
				break
			cc = opts[0]
		var nc := course.next_corner(en["piece"])
		if not nc.is_empty():
			var side: float = clamp(float(en["lat"]) / course.lane_w, -2.5, 2.5)
			s += side * (1.5 if nc["turn"] == "R" else -1.5)
	if course.huts.has(int(o["end"])) and (p.dents > 0 or p.half) and String(o["crash"]) == "":
		# l'officina ripara metà dei danni: vale di più con tanti danni
		var units := p.dents * 2 + (1 if p.half else 0)
		s += 6.0 + float(units - units / 2) * 6.0 + (10.0 if p.dents >= 3 else 0.0)
	if (o["path"] as Array).is_empty():
		s -= 12.0 + 60.0 * p.stalls
	if not fin:
		# vicolo cieco vicino: al prossimo turno servirà derivare
		var run: int = int(en.get("run", 99))
		if run < max(S2, 1):
			s -= 6.0 * (max(S2, 1) - run)
	s -= abs(d2) * 1.5 + n_cards * 0.5
	return s + randf() * 3.0

## Uno sguardo al turno dopo, sulle caratteristiche fanmade: velocità sprecata in salita,
## vento che spingerà contro il bordo, sabbia già spazzata da seguire.
static var ai_parts := {"up": false, "wind": true, "fresh": true, "down": true, "ply2": true}
func _ai_lookahead(p: Player, o: Dictionary, S2: int, d2: int) -> float:
	var s := 0.0
	var end: int = o["end"]
	var reach: int = max(S2, 1) + 1
	# salita davanti: con la plancia veloce si sprecheranno punti (e in salita si arriva lenti)
	var id := end
	for k in (reach + 1 if ai_parts["up"] else 0):
		if course.slope_of(id) == "up":
			s -= float(min(S2, UP_LOSS)) * 1.5
			break
		var fw: Array = cell(id)["fwd"]
		if fw.is_empty():
			break
		id = fw[0]
	# vento: al prossimo turno sposterà di S2/2 corsie; conviene avere spazio da quel lato
	var w := course.wind_of(end)
	if w != 0 and S2 > 1 and ai_parts["wind"]:
		var pushes: int = WIND_PUSH
		var room := 0
		var cc := end
		for i in pushes:
			var t: int = cell(cc).get("side_r" if w > 0 else "side_l", -1)
			if t < 0:
				break
			room += 1
			cc = t
		if room < pushes:
			s -= float(pushes - room) * 9.0
		# derivare contro vento lo compensa
		if d2 != 0 and signi(d2) == -w:
			s += 3.0
	# sabbia intatta proprio davanti: meglio una corsia già spazzata
	var fw2: Array = cell(end)["fwd"]
	if ai_parts["fresh"] and not fw2.is_empty() and fresh.has(fw2[0]):
		s -= 3.0
	return s

func ai_discard(p: Player) -> void:
	for v in ai_discard_values(p):
		p.hand.erase(v)
		p.discard.append(v)

## Le carte che la CPU scarterebbe (senza toccare la mano): servono anche quando, online,
## il computer prende il posto di un giocatore che si è scollegato.
func ai_discard_values(p: Player) -> Array:
	var hand: Array = p.hand.duplicate()
	var out := []
	while hand.size() + p.dents > 5 and not hand.is_empty():
		var counts := {}
		for v in hand:
			counts[v] = counts.get(v, 0) + 1
		var bestv: int = hand[0]
		for v in counts.keys():
			if counts[v] > counts[bestv] or (counts[v] == counts[bestv] and v > bestv):
				bestv = v
		hand.erase(bestv)
		out.append(bestv)
	return out

# ---------- Ion Tails: punti gadget ----------
## Scorta di punti di ogni navetta: un punto ogni BUDGET_DIV passi dalla partenza al traguardo.
static func budget_for(c: Course) -> int:
	if c.start_cells.is_empty():
		return 10
	var togo := int(c.cells[c.start_cells[min(2, c.start_cells.size() - 1)]].get("togo", 40))
	return max(6, int(round(float(togo) / BUDGET_DIV)))

## Inizio turno: via le scelte del turno prima.
func energy_round_start() -> void:
	smoke = {}
	for p in players:
		p.al = {}
		p.drag = 0

static func gadget_name(k: String) -> String:
	return String(GADGETS[k][0])

static func level(a: Dictionary, k: String) -> int:
	return clampi(int(a.get(k, 0)), 0, MAX_LEVEL)

## Punti richiesti da una scelta.
static func alloc_cost(a: Dictionary) -> int:
	var c := 0
	for k in GADGET_ORDER:
		c += level(a, k)
	return c

func player_by_id(id: int) -> Player:
	for q in players:
		if q.id == id:
			return q
	return null

## La scelta è valida? (punti sufficienti, bersaglio del cecchino in gara e non la navetta stessa)
func alloc_ok(p: Player, a: Dictionary) -> bool:
	if alloc_cost(a) > p.energy:
		return false
	if level(a, "sn") > 0:
		var q := player_by_id(int(a.get("snt", -1)))
		if q == null or q == p or not racing(q):
			return false
	return true

## Applica la scelta (se non valida, nessun gadget): punti spesi, settori del radar.
func apply_alloc(p: Player, a: Dictionary) -> void:
	var clean := {}
	for k in GADGET_ORDER:
		var lv := level(a, k)
		if lv > 0:
			clean[k] = lv
	if clean.has("sn"):
		clean["snt"] = int(a.get("snt", -1))
	if not alloc_ok(p, clean):
		clean = {}
	var c := alloc_cost(clean)
	p.energy -= c
	p.spent += c
	if clean.has("ra") and p.cell >= 0:
		var pc := int(cell(p.cell)["piece"])
		clean["ra0"] = pc
		clean["ra1"] = pc + int(clean["ra"]) - 1
	p.al = clean

## Dopo le scelte di tutti: l'arpione rallenta subito il bersaglio per questo turno.
func apply_hooks() -> Array:
	var out := []
	for p in players:
		var lv := level(p.al, "ho")
		if lv <= 0 or not racing(p):
			continue
		var t := hook_target(p)
		if t != null:
			t.drag += lv
			p.al["hot"] = t.id
			out.append({"by": p, "to": t, "lv": lv})
	return out

## Altre navette in pista (non distrutte).
func _on_track(p: Player) -> Array:
	var out := []
	for q in players:
		if q != p and not q.wrecked and q.cell >= 0:
			out.append(q)
	return out

## La navetta più vicina davanti (in passi dal traguardo), entro range passi.
func _ahead(p: Player, from_cell: int, rng_max: int) -> Player:
	if from_cell < 0:
		return null
	var my_togo := int(cell(from_cell)["togo"])
	var best: Player = null
	var bd := 999
	for q in _on_track(p):
		if q.finish_round != 0:
			continue
		var d: int = my_togo - int(cell(q.cell)["togo"])
		if d >= 0 and d <= rng_max and d < bd and q.cell != from_cell:
			bd = d
			best = q
	return best

const HOOK_RANGE := 6
func hook_target(p: Player) -> Player:
	return _ahead(p, p.cell, HOOK_RANGE)

## Velocità in più (o in meno) per la mossa di p: postbruciatore e arpione subito.
func speed_extra(p: Player) -> int:
	if not energy_on:
		return 0
	return level(p.al, "bo") - p.drag

## Mine viste da p: le proprie sempre, le altre col radar nei settori coperti.
func sees_mine(p: Player, cell_id: int) -> bool:
	if not mines.has(cell_id):
		return false
	if int(mines[cell_id]) == p.id:
		return true
	if level(p.al, "ra") <= 0:
		return false
	var pc := int(cell(cell_id)["piece"])
	return pc >= int(p.al.get("ra0", 0)) and pc <= int(p.al.get("ra1", -1))

## Corsie fra la casella e il bordo più vicino (0 = sul bordo), e il lato del bordo (-1 sx, 1 dx).
func edge_info(cell_id: int) -> Array:
	var nl := 0
	var c := cell_id
	while nl < 6 and int(cell(c).get("side_l", -1)) >= 0:
		c = int(cell(c)["side_l"])
		nl += 1
	var nr := 0
	c = cell_id
	while nr < 6 and int(cell(c).get("side_r", -1)) >= 0:
		c = int(cell(c)["side_r"])
		nr += 1
	return [min(nl, nr), -1 if nl <= nr else 1]

## Probabilità che il cecchino colpisca: precisione dai punti, meno per la velocità del
## bersaglio e per la distanza dalle pareti del canyon, meno lo scudo.
func sniper_chance(lv: int, speed: int, lanes_from_edge: int, shield: int) -> float:
	var p: float = 0.3 + 0.2 * lv - 0.04 * max(0, speed - 4) - 0.08 * lanes_from_edge - 0.3 * shield
	return clamp(p, 0.0, 0.95)

## Casella davanti nella stessa corsia (la più dritta) o -1.
func _straight(c: int) -> int:
	var fw: Array = cell(c)["fwd"]
	if fw.is_empty():
		return -1
	var h := course.heading(c)
	var best: int = fw[0]
	var bd := -INF
	for f in fw:
		var d: float = (cell(f)["pos"] - cell(c)["pos"]).normalized().dot(h)
		if d > bd:
			bd = d
			best = f
	return best

## Volo del missile da from_cell: dritto per range caselle; le CME del bersaglio possono
## farlo cambiare corsia o esplodere. Restituisce {cells, hits: [{pid, res}]}.
func _missile(p: Player, from_cell: int, range_n: int, msgs: Array) -> Dictionary:
	var cells := [from_cell]
	var c := from_cell
	var left := range_n
	var occ := {}
	for q in _on_track(p):
		if q.finish_round == 0:
			occ[q.cell] = q
	var deflected := 0
	while left > 0:
		var n := _straight(c)
		if n < 0:
			msgs.append("il missile si schianta contro il fondo della gola")
			return {"cells": cells, "res": "wall"}
		c = n
		cells.append(c)
		left -= 1
		while occ.has(c):
			var q: Player = occ[c]
			var cm := level(q.al, "cm")
			if cm >= 3:
				msgs.append("le CME di %s fanno esplodere il missile" % q.name)
				return {"cells": cells, "res": "boom", "pid": q.id}
			if (cm == 2 or (cm == 1 and rng.randf() < 0.5)) and deflected < 2:
				deflected += 1
				var side := "side_l" if rng.randf() < 0.5 else "side_r"
				var s2 := int(cell(c).get(side, -1))
				if s2 < 0:
					s2 = int(cell(c).get("side_r" if side == "side_l" else "side_l", -1))
				msgs.append("le CME di %s deviano il missile" % q.name)
				occ.erase(c)
				if s2 < 0:
					return {"cells": cells, "res": "wall"}
				c = s2
				cells.append(c)
				continue
			var sh := level(q.al, "sh")
			if sh > 0 and rng.randf() < 0.15 * sh:
				msgs.append("lo scudo di %s regge al missile" % q.name)
				return {"cells": cells, "res": "shield", "pid": q.id}
			add_dent(q, 1)
			msgs.append("il missile colpisce %s (+1 a lei)%s" % [q.name, ": va in pezzi!" if q.wrecked else ""])
			return {"cells": cells, "res": "hit", "pid": q.id}
	msgs.append("il missile si perde nel canyon")
	return {"cells": cells, "res": "miss"}

func _straight_back(c: int) -> int:
	var bw: Array = cell(c).get("bwd", [])
	return int(bw[0]) if not bw.is_empty() else -1

## Effetti dei gadget a fine mossa (prima che si contino i danni): mine sul percorso,
## mine sganciate, cecchini, missile, blast ionico. Aggiunge i danni a o["dents"] e gli
## effetti visivi a o["gfx"].
func _gadgets_after_move(p: Player, o: Dictionary, msgs: Array) -> void:
	var gfx := []
	var from: int = int(o.get("from", -1))
	var path: Array = o["path"]
	var end: int = int(o["end"])
	if not path.is_empty():
		p.cell = end
	var extra := 0
	var bo := level(p.al, "bo")
	if bo > 0 and not path.is_empty():
		msgs.append("postbruciatore (+%d)" % bo)
		gfx.append({"k": "boost", "pid": p.id})
	if p.drag > 0:
		msgs.append("trattenuta dall'arpione (−%d)" % p.drag)
	# mine sul percorso (tranne le proprie)
	var boom := []
	for t in path:
		if mines.has(t) and int(mines[t]) != p.id:
			boom.append(t)
			mines.erase(t)
	if not boom.is_empty():
		extra += boom.size()
		msgs.append("%s (+%d)" % ["salta su una mina" if boom.size() == 1 else "salta su %d mine" % boom.size(), boom.size()])
		for t in boom:
			gfx.append({"k": "mine", "cell": t})
	# mine sganciate sulle caselle lasciate dietro (dall'ultima prima dell'arrivo indietro)
	var mi := level(p.al, "mi")
	if mi > 0 and not path.is_empty():
		var behind := []
		for i in range(path.size() - 2, -1, -1):
			behind.append(int(path[i]))
		if from >= 0:
			behind.append(from)
		var dropped := 0
		for t in behind:
			if dropped >= mi:
				break
			if t == end or mines.has(t):
				continue
			mines[t] = p.id
			dropped += 1
			gfx.append({"k": "drop", "cell": t, "pid": p.id})
		if dropped > 0:
			msgs.append("sgancia %s" % ("una mina" if dropped == 1 else "%d mine" % dropped))
	# cecchini puntati su questa navetta
	var spd := int(o.get("speed", 0))
	var ei := edge_info(end)
	for q in players:
		if q == p or level(q.al, "sn") <= 0 or int(q.al.get("snt", -1)) != p.id:
			continue
		var ch := sniper_chance(level(q.al, "sn"), spd, int(ei[0]), level(p.al, "sh"))
		var hit := rng.randf() < ch
		var pct := int(round(ch * 100.0))
		if hit:
			extra += 1
			msgs.append("colpita dal cecchino di %s (+1, mira %d%%)" % [q.name, pct])
		elif level(p.al, "sh") > 0:
			msgs.append("lo scudo devia il colpo del cecchino di %s (mira %d%%)" % [q.name, pct])
		else:
			msgs.append("il cecchino di %s la manca (mira %d%%)" % [q.name, pct])
		gfx.append({"k": "laser", "by": q.id, "pid": p.id, "res": "hit" if hit else ("shield" if level(p.al, "sh") > 0 else "miss")})
	# missile dritto davanti
	var ms := level(p.al, "ms")
	if ms > 0:
		var r := _missile(p, end, 3 + 2 * ms, msgs)
		r["k"] = "missile"
		r["by"] = p.id
		gfx.append(r)
	# blast ionico sulla navetta più vicina davanti
	var bl := level(p.al, "bl")
	if bl > 0:
		var t := _ahead(p, end, 3)
		if t == null:
			msgs.append("il blast ionico va a vuoto")
		else:
			var ti := edge_info(t.cell)
			var side := "side_l" if int(ti[1]) < 0 else "side_r"
			var c := t.cell
			var moved := 0
			var crashed := false
			var occ := {}
			for q in players:
				if not q.wrecked and q.cell >= 0:
					occ[q.cell] = true
			for k in bl:
				var n := int(cell(c).get(side, -1))
				if n < 0:
					crashed = true
					break
				if occ.has(n):
					break
				c = n
				moved += 1
			var from_c := t.cell
			t.cell = c
			if crashed:
				add_dent(t, 1)
			msgs.append("il blast ionico sposta %s di %d corsi%s%s" % [t.name, moved, "a" if moved == 1 else "e", " contro il bordo (+1 a lei)" if crashed else ""])
			gfx.append({"k": "blast", "pid": p.id, "to": t.id, "from": from_c, "cell": c})
	if extra > 0:
		o["dents"] = int(o["dents"]) + extra
	o["gfx"] = gfx

## Turni che mancano, stimati dai passi al traguardo.
func _rounds_left(p: Player) -> float:
	if p.cell < 0:
		return 1.0
	return max(1.0, float(int(cell(p.cell)["togo"])) / 5.0)

# ---------- CPU: punti gadget ----------
## Scelta dei gadget per la CPU (usa randf, non il generatore della partita: online la fa
## solo chi ha creato la stanza e la pubblica). Spende in modo da arrivare in fondo.
func ai_alloc(p: Player) -> Dictionary:
	var a := {}
	if p.energy <= 0 or p.cell < 0:
		return a
	var rate: float = float(p.energy) / _rounds_left(p)
	var spend := int(floor(rate * 1.3 + randf()))
	spend = clampi(spend, 0, p.energy)
	if spend <= 0:
		return a
	var order := race_order()
	var rank := order.find(p)
	var c0 := cell(p.cell)
	var opts := []
	# attacchi
	if order.size() > 1:
		var tgt: Player = order[0] if rank > 0 else order[1]
		if rank > 1 and randf() < 0.4:
			tgt = order[rank - 1]
		opts.append(["sn", 1.2 + (0.6 if rank > 0 else 0.0), tgt.id])
	var behind := 0
	for q in _on_track(p):
		var d: int = int(cell(q.cell)["togo"]) - int(c0["togo"])
		if d >= 1 and d <= 5:
			behind += 1
	if behind > 0:
		opts.append(["mi", 0.8 + behind * 0.3, -1])
	if _ahead(p, p.cell, 8) != null:
		opts.append(["ms", 1.0, -1])
		opts.append(["bl", 0.8, -1])
		opts.append(["ho", 1.2, -1])
	# difese
	if rank <= 1:
		opts.append(["sh", 2.2 if rank == 0 else 1.4, -1])
	if behind > 0:
		opts.append(["cm", 0.6 + behind * 0.4, -1])
	if p.dents >= 2:
		opts.append(["sh", 1.5 + p.dents * 0.5, -1])
	if mines.size() > 0:
		opts.append(["ra", 0.8 + 0.3 * mines.size(), -1])
	# movimento: postbruciatore lontano dalle curve
	var nl := course.next_limit(float(c0["s"]))
	if nl.is_empty() or (float(nl["s"]) - float(c0["s"])) / course.cell_len > 10.0:
		opts.append(["bo", 1.6, -1])
	if opts.is_empty():
		return a
	while spend > 0 and not opts.is_empty():
		var tot := 0.0
		for o in opts:
			tot += float(o[1])
		var r := randf() * tot
		var pick: Array = opts[0]
		for o in opts:
			r -= float(o[1])
			if r <= 0:
				pick = o
				break
		var k: String = pick[0]
		var lv: int = min(spend, 1 + (1 if randf() < 0.35 else 0))
		lv = min(lv, MAX_LEVEL - level(a, k))
		if lv <= 0:
			opts.erase(pick)
			continue
		a[k] = level(a, k) + lv
		if k == "sn":
			a["snt"] = pick[2]
		spend -= lv
		if randf() < 0.5:
			opts.erase(pick)
	if not alloc_ok(p, a):
		return {}
	return a
