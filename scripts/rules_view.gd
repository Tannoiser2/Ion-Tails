class_name RulesView
extends VBoxContainer
## Pagina delle regole: sezioni a schede (come si gioca, interfaccia, pista, gadget, officina,
## stanze e varianti, comandi). Ogni gadget ha il suo token con livelli ed effetti.

signal section_changed(id: String)
signal fan_requested

const SECTIONS := [
	["play", "Come si gioca"],
	["ui", "Interfaccia"],
	["track", "Pista"],
	["gadget", "Gadget"],
	["shop", "Officina"],
	["room", "Stanze e varianti"],
	["keys", "Comandi"],
]

## Un gadget: [chiave, effetto con 1 punto, effetto con 2 punti, note]. Nome e categoria vengono da SledGame.
const GADGET_TEXT := {
	"sn": ["Spara alla navetta scelta, mira 55%.", "Mira 80%.",
		"Il bersaglio si sceglie con i pulsanti «su …» che compaiono sotto il gadget. Il colpo parte quando il bersaglio ha finito la sua mossa, dal canyon. La mira cala di 4 punti percentuali per ogni punto di velocità del bersaglio oltre 4 e di 8 per ogni corsia che lo separa dalla parete più vicina; ogni punto di scudo la riduce di 40. Un colpo a segno fa mezzo danno. Non si può mirare a chi è invisibile; se il bersaglio ha l'esca a 2 punti, il colpo va all'esca."],
	"mi": ["Una mina sulle caselle che ti lasci dietro.", "Due mine.",
		"Chi ci passa sopra prende mezzo danno (tu no). Restano in pista finché qualcuno non ci passa. Sono segrete: le vedi tu, per le tue, e chi ha il radar. Colpiscono anche chi è invisibile; il salto gravitazionale a 2 punti le scavalca."],
	"ms": ["Missile guidato dritto davanti, nella tua corsia: gittata 7 caselle.", "Gittata 10 caselle.",
		"Parte a fine mossa e colpisce la prima navetta visibile che incontra: mezzo danno. Lo scudo lo ferma solo il 20% (1 punto) o il 40% (2 punti) delle volte; le CME lo deviano o lo fanno esplodere; l'esca lo assorbe."],
	"em": ["A fine mossa spegne scudo, CME, radar, esca e ancora delle navette entro 1 casella.", "Entro 2 caselle.",
		"Vale per il resto del turno e colpisce davanti, dietro e di lato. Appare un'onda elettrica e la scritta «IMPULSO EMP»."],
	"sc": ["Le ultime 2 caselle che ti lasci dietro diventano sabbia.", "Le ultime 4 caselle.",
		"Entrare in una casella di sabbia costa 2 punti di movimento invece di 1; la prima navetta che ci passa la spazza via."],
	"si": ["Appena tutti hanno scelto, ruba 1 punto gadget alla navetta più vicina.", "Ruba 3 punti gadget.",
		"Vale per la navetta più vicina, davanti o dietro, entro 6 passi. Il bottino si aggiunge alla tua scorta: compare la scritta «SIFONE +n»."],
	"sh": ["Bolla azzurra: toglie il 40% alla mira dei cecchini; ferma i missili il 20% delle volte.", "Toglie l'80%; ferma i missili il 40% delle volte.",
		"Si accende quando la navetta parte (prima lo vedi solo tu) e dura per tutto il turno. Contro i missili, che arrivano da dietro, protegge meno che contro i cecchini."],
	"ra": ["Vedi le mine fino a 12 caselle davanti a te.", "Fino a 24 caselle.",
		"Vedi anche le 3 caselle appena dietro. La rotta evita le mine quando può. A inizio turno un'onda verde parte dalla navetta e una scritta dice quante mine ha trovato."],
	"cm": ["Il missile in arrivo cambia corsia.", "Il missile esplode.",
		"Con 1 punto va verso un'altra navetta nelle corsie accanto, se ce n'è una a tiro (e può colpirla); altrimenti il lato è a caso."],
	"iv": ["Sparisci alla vista degli altri per questo turno.", "Anche per il turno seguente.",
		"Tu ti vedi come una sagoma olografica azzurra. Cecchini, missili, arpione e blast non ti trovano, ma tu puoi continuare a sganciare mine e a sparare. Le mine colpiscono anche chi è invisibile."],
	"ec": ["Un tuo doppio olografico: il primo missile che ti arriva colpisce l'esca.", "Anche i cecchini sparano all'esca.",
		"Quando l'esca viene colpita compare la scritta «ESCA COLPITA»; l'impulso EMP la spegne."],
	"nb": ["A fine mossa riparano mezzo danno.", "Riparano un danno intero.",
		"Compare la scritta «NANOBOT: RIPARATA». Non si può riparare più dei danni che si hanno."],
	"an": ["Per questo turno arpione e blast ionico non ti spostano.", "(un solo livello)",
		"Costa 1 punto e ha un solo tasto. Compare la scritta «ANCORATA». L'impulso EMP la spegne."],
	"bo": ["+1 alla velocità di questa mossa.", "+2.",
		"Conta anche per i limiti delle curve: attenzione a non esagerare."],
	"ho": ["Tira indietro di 1 casella la navetta più vicina davanti a te.", "Di 2 caselle.",
		"Vale subito, appena tutti hanno scelto i gadget: si vede l'arpione partire, agganciare e tirare. Cerca davanti a te fino a 6 passi (non le navette di fianco) e funziona solo se dietro di lei c'è posto."],
	"bl": ["Onda dalla tua casella: spinge di una corsia lontano da te le navette entro 1 casella.", "Entro 2 caselle.",
		"Vale a fine mossa, davanti, dietro e di lato; chi è nella tua corsia va verso il bordo più vicino. Chi sbatte contro il bordo prende mezzo danno; se la casella accanto è occupata resta dov'è."],
	"st": ["+1 al limite delle curve in questa mossa.", "+2.",
		"Si somma al limite scritto nel cerchio rosso, ma non cambia la velocità."],
	"sa": ["In questa mossa scavalchi le altre navette.", "Scavalchi anche le mine.",
		"Puoi attraversare le caselle occupate, ma non fermarti su una già occupata."],
}

var main
var fan := false
var wide := true
var section := "play"
var _tabs: Dictionary = {}
var _scroll: ScrollContainer
var _body: VBoxContainer

func _init(m, with_fan: bool, is_wide: bool, start := "play") -> void:
	main = m
	fan = with_fan
	wide = is_wide
	section = start
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for s in SECTIONS:
		var b := UIKit.button(s[1])
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 18)
		var id: String = s[0]
		b.pressed.connect(func(): show_section(id))
		row.add_child(b)
		_tabs[id] = b
	add_child(row)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	show_section(section)

func show_section(id: String) -> void:
	section = id
	section_changed.emit(id)
	for k in _tabs:
		var b: Button = _tabs[k]
		if k == id:
			UIKit.style_button(b, Color(UIKit.ACCENT, 0.35), UIKit.INK, UIKit.ACCENT, 3, 12)
		else:
			UIKit.style_button(b, UIKit.SOFT, UIKit.MUTED, UIKit.LINE, 1, 12)
	UIKit.clear(_body)
	_scroll.scroll_vertical = 0
	match id:
		"play": _play()
		"ui": _ui()
		"track": _track()
		"gadget": _gadgets()
		"shop": _shop()
		"room": _room()
		"keys": _keys()

# ---------- elementi ----------
func _h(t: String) -> void:
	_body.add_child(UIKit.heading(t, 20))

func _t(t: String) -> void:
	var r: RichTextLabel = main._rule_text(t)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(r)

func _box(color: Color, title: String, text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(color, 0.10), 12, Color(color, 0.55), 2, 10))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var l := UIKit.label(title, 20, color.lightened(0.3))
	l.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
	v.add_child(l)
	var r: RichTextLabel = main._rule_text(text)
	v.add_child(r)
	return pc

## Elenco a due colonne sugli schermi larghi.
func _grid(items: Array) -> void:
	var g := GridContainer.new()
	g.columns = 2 if wide else 1
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		g.add_child(it)
	_body.add_child(g)

func _item(icon: Control, title: String, text: String) -> HBoxContainer:
	var h: HBoxContainer = main._rule_item(icon, title, text)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _img(path: String, w := 84.0, h := 64.0) -> Control:
	return main._rule_img(path, w, h)

# ---------- come si gioca ----------
func _play() -> void:
	_h("Lo scopo")
	_t("Tagliare il traguardo per primi con la propria navetta, senza distruggerla. Si corre finché tutte le navette hanno tagliato il traguardo (o sono distrutte): in classifica conta prima il turno in cui si taglia il traguardo, poi chi è andato più lontano oltre la linea.")
	_h("La navetta")
	_t("""Un abitacolo trainato da [b]due motori[/b], più il [b]freno[/b]: sulla plancia ci sono tre spazi per le carte, tutti a 3 all'inizio. [b]Velocità[/b] = motore sinistro + motore destro − freno. [b]Deriva[/b] = differenza fra i motori: ti sposti di lato verso il motore più forte (mai più della velocità), nei passi che scegli tu. Il mazzo è di 20 carte, da 1 a 5 (quattro per valore, se non lo cambi in officina); in mano ne hai 5.""")
	_h("La partenza")
	_t("Si comincia con lo [b]schieramento[/b]: a turno ognuno tocca uno dei cerchi numerati sulla griglia di partenza (da 1 a 5). La 4ª e la 5ª posizione in griglia partono con carte in più.")
	_h("La mossa")
	_t("""Quando tocca a te giochi da 1 a 3 carte dello stesso valore, al massimo una per spazio. Le carte sui motori restano sulla plancia; quella sul freno lo imposta e va negli scarti. Poi scegli sulla pista la casella d'arrivo, la navetta muove e torni a 5 carte. I [b]danni[/b] sono carte inutili che occupano posto in mano e non si scartano: più danni hai, meno carte buone ti restano. Se hai troppe carte in mano devi scartarne.""")
	_h("Ordine")
	_t("A ogni turno muove prima chi è in testa, poi gli altri in ordine di posizione. Prima di muovere, ognuno sceglie in segreto i gadget (vedi la scheda «Gadget»).")
	_h("Equilibrio")
	_t("Con i motori uguali e nessuna deriva puoi aggiungere un [b]bonus[/b] pari alla tua posizione in classifica, tutto dritto, a fine movimento. Non vale al primo turno.")
	_h("Pericoli")
	_t("""[b]Curva[/b] oltre il limite: un danno per ogni punto di troppo (il bonus conta). [b]Bordo[/b] della pista, dune e crepacci: ti fermi e prendi un danno. [b]Tamponamento[/b]: ti fermi dietro l'altra navetta e non peschi. [b]Gola[/b] saltata troppo piano: un danno per ogni punto che manca. [b]Massi[/b]: un danno per ogni masso. Al quinto danno la navetta è distrutta (in officina puoi scegliere uno scafo che ne regge meno o più). Anche i gadget fanno danni, ma [b]mezzi danni[/b]: ne servono due per uno intero.""")

# ---------- interfaccia ----------
func _ui() -> void:
	_h("Il menu")
	_grid([
		_box(Color("e8601c"), "Gara", "Scegli il percorso (dalla lista, con il Gran Tour, oppure una pista casuale), le navette e chi le guida: Bot, Umano su questo schermo, Online o Telefono. In basso: «Entra in una stanza» e «Inizia la gara» (diventa «Crea la stanza» se ci sono posti online)."),
		_box(Color("1f8fe8"), "Editor", "Crea e modifica i tuoi percorsi con le tessere del canyon, mappa le tessere e collega la libreria online."),
		_box(Color("e8a81c"), "Officina", "Costruisci la tua navetta con 15 crediti, salvala e pubblicala nella galleria online."),
		_box(Color("9a4fe0"), "Regole", "Questa pagina. Si apre anche in gara dal tasto «Regole» in alto."),
	])
	_h("Lo schermo di gara")
	_t("In orizzontale la pista occupa lo schermo e a destra c'è il pannello dei comandi; in verticale (telefono) il pannello è sotto e due schede in alto, [b]Navetta e carte[/b] e [b]Pista[/b], alternano la vista (si apre da sola quella che serve). Con un dito si trascina la pista, con due si avvicina e si ruota.")
	_shot("res://assets/rules/ui_gara.webp", 1280.0 / 800.0, [
		["Barra in alto", "Tre tasti: [b]Segui[/b] (la telecamera segue la navetta di turno), [b]Regole[/b] e [b]Menu[/b] (torna al menu, con «Torna alla gara» se la partita è in corso)."],
		["Turno e chi gioca", "Il numero del turno e la navetta che deve muovere; «(tu)» vuol dire che tocca a te."],
		["La classifica", "Una targhetta per navetta, in ordine di posizione: «1 Rosso D2 ½» vuol dire prima, con 2 danni e mezzo danno. [b]D[/b] = danni, [b]½[/b] = mezzo danno, «fine» = ha tagliato il traguardo, «KO» = distrutta, «? invisibile» = nascosta da un gadget. Il bordo colorato indica chi gioca."],
		["I numeri della navetta", "[b]Velocità[/b], [b]Deriva[/b] (con il verso: dx o sx), [b]Bonus[/b] di equilibrio e che cosa c'è davanti (limite della curva, traguardo, salto, tratti fanmade) e fra quante caselle. Diventano rossi quando stai per prendere un danno. Il tasto [b]Percorsi[/b] mostra sulla pista tutti i percorsi possibili con le carte messe sulla plancia."],
		["Il riquadro dei messaggi", "Dice che cosa fare ora (scegliere la partenza, programmare, toccare la casella d'arrivo) e, in grigio, che cosa è successo nell'ultima mossa."],
		["La plancia", "Tre spazi: motore sinistro, freno e motore destro. A sinistra il [b]mazzo[/b] (quante carte restano), a destra gli [b]scarti[/b]. Si tocca una carta della mano e poi lo spazio dove metterla."],
		["La mano", "Le tue carte da 1 a 5 (con i danni, che occupano posto). In fondo: [b]Riprendi le carte[/b] annulla le scelte, [b]Muovi la navetta[/b] (nel simultaneo [b]Programma[/b]) conferma, [b]Cambia carte[/b] torna indietro dopo aver visto le destinazioni."],
		["Cambia carte", "Quando stai scegliendo la destinazione puoi tornare alle carte."],
		["Le destinazioni", "Anelli che pulsano sulla pista: sono le caselle dove puoi arrivare. Il numero rosso [b]−n[/b] sono i danni che prendi arrivando lì, [b]+B[/b] il bonus; la linea sottile col puntino è la strada che farà la navetta, il tratto largo e chiaro una deriva. Tocca l'anello che vuoi."],
	])
	_h("Il pannello dei gadget")
	_t("All'inizio di ogni turno si apre in segreto, prima di muovere: ognuno sceglie da solo, mentre gli altri aspettano. Mostra solo i gadget che hai montato.")
	_shot("res://assets/rules/ui_gadget.webp", 590.0 / 800.0, [
		["Punti rimasti", "I punti gadget che ti restano, in grande, con il nome della navetta (se non è quella di serie)."],
		["Conto alla rovescia", "I secondi che restano per scegliere; allo scadere vale la scelta fatta fin lì."],
		["Livello 1", "Ogni gadget ha due tasti col suo token: il numero è il livello, cioè quanti punti spendi. Se ne accende al massimo uno; toccando quello acceso si spegne. I gadget sono in tre gruppi: Attacchi, Difese, Movimento."],
		["Livello 2", "Costa 2 punti e ha l'effetto più forte (gittata, mira o durata maggiori)."],
		["Bersaglio del cecchino", "Col cecchino acceso compaiono i pulsanti «su …», uno per navetta: scegli chi colpire."],
		["Azzera e Conferma", "[b]Azzera[/b] toglie tutte le scelte; [b]Conferma[/b] chiude la tua scelta (anche senza gadget)."],
	])
	_h("Gli effetti in pista")
	_t("I gadget si scoprono quando agiscono: raggi, esplosioni, bolle, onde e scritte sopra le navette («ESCA COLPITA», «ANCORATA», «NANOBOT: RIPARATA»…). Le mine sono segrete: le vedi solo se sono tue o se hai il radar.")
	_h("Replay e risultati")
	_t("A fine gara il tasto [b]Classifica[/b] mostra posizione, turni, danni e navetta di ognuno; da lì si rivede la gara. Il replay muove tutte le navette insieme, con gli effetti nel punto giusto. Comandi: [b]Pausa[/b]/[b]Riprendi[/b], [b]Velocità ×n[/b] e [b]Esci dal replay[/b].")

## Schermata di gioco con i numeri e, accanto, la spiegazione di ognuno.
func _shot(path: String, aspect: float, legend: Array) -> void:
	var h: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := 640.0 if wide else 440.0
	tr.custom_minimum_size = Vector2(w, w / aspect)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in legend.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nb := UIKit.label(str(i + 1), 20, Color.WHITE)
		nb.add_theme_font_override("font", UIKit.font(UIKit.F_BLACK))
		nb.add_theme_stylebox_override("normal", UIKit.box(Color("e8601c"), 14, Color.WHITE, 2, 2))
		nb.custom_minimum_size = Vector2(34, 34)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nb.autowrap_mode = TextServer.AUTOWRAP_OFF
		nb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(nb)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var tt := UIKit.label(String(legend[i][0]), 19, UIKit.HEAD)
		tt.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
		col.add_child(tt)
		var rt: RichTextLabel = main._rule_text(String(legend[i][1]))
		col.add_child(rt)
		row.add_child(col)
		v.add_child(row)
	h.add_child(v)
	_body.add_child(h)

# ---------- pista ----------
func _track() -> void:
	_h("Sulla pista")
	_grid([
		_item(_img("res://assets/rules/limit.png"), "Limite della curva", "Il numero nel cerchio rosso, all'ingresso di curve e inversioni, è la velocità massima. Ogni punto in più (bonus compreso) è un danno."),
		_item(_img("res://assets/rules/leap_sign.png"), "Salto della gola", "La spaccatura fra i due cartelli va saltata a velocità 5 o più; per ogni punto che manca, un danno. Chi si ferma sulle caselle della spaccatura non pesca."),
		_item(_img("res://assets/rules/sapling.png"), "Massi", "Chi entra in una casella con un masso lo travolge e prende un danno per ogni masso. Poi il masso sparisce."),
		_item(_img("res://assets/tiles/snowdrift_p15a.webp", 92, 70), "Dune e crepacci", "Chiudono alcune corsie: sono come il bordo della pista, chi ci finisce contro si ferma e prende un danno."),
		_item(_img("res://assets/tiles/start_p21.webp", 70, 72), "Partenza e traguardo", "Si sceglie a turno la casella di partenza, numerate da 1 a 5. Il traguardo è la linea rossa: conta quanto si va oltre."),
	])
	_h("Segni del gioco")
	_grid([
		_item(RuleIcon.new("dest"), "Destinazioni", "Gli anelli che pulsano sono le caselle dove puoi arrivare: tocca quella che vuoi."),
		_item(RuleIcon.new("path"), "Percorso", "La linea sottile col puntino in ogni casella è la strada che farà la navetta."),
		_item(RuleIcon.new("drift"), "Deriva", "Il tratto largo e chiaro è uno spostamento di lato verso il motore più forte."),
		_item(RuleIcon.new("dent"), "Danni", "Il numero rosso sopra una destinazione dice quanti danni prendi arrivando lì."),
	])
	if fan:
		_h("Segmenti fanmade")
		_grid([
			_item(_img("res://assets/fan/sign_up.png", 64, 64), "Salita", "Chi parte da una tessera in salita ha %d punti di velocità in meno, come un freno in più (non si va sotto zero)." % SledGame.UP_LOSS),
			_item(_img("res://assets/fan/sign_down.png", 64, 64), "Discesa", "Chi parte da una tessera in discesa guadagna 1 punto di velocità ogni %d: a 3 va a 4, a 6 va a 8, a 9 va a 12." % SledGame.DOWN_PER),
			_item(_img("res://assets/fan/sign_fresh.png", 64, 64), "Sabbia", "Ogni casella coi cumuli costa 2 punti di movimento; la prima navetta che ci passa la spazza via. I cumuli cambiano posto a ogni gara."),
			_item(_img("res://assets/fan/sign_ice.png", 64, 64), "Vetro", "Chi entra derivando continua a derivare finché è sul vetro; a fine movimento scivola avanti di una casella."),
			_item(_img("res://assets/fan/sign_wind.png", 64, 64), "Tempesta di sabbia", "La forza è 1, 2 o 3 (a volte tirata a sorte a inizio gara). Vento di lato: chi parte dalla tessera ha tanta deriva in più nel verso della manica a vento, sommata a quella dei motori (o tolta, se va dall'altra parte); il bonus di equilibrio vale solo con deriva totale zero. Vento a favore: tanta velocità in più; vento contrario: tanta in meno."),
			_item(_img("res://assets/fan/sign_hut.png", 64, 64), "Officina", "Chi si ferma sulla casella accanto all'officina ripara metà dei danni (arrotondando a suo favore), ma non pesca."),
			_item(_img("res://assets/rules/fork_sign.png", 64, 64), "Bivio", "Uno sperone di roccia divide la pista in due rami con un numero diverso di caselle: da una parte sabbia, dall'altra massi."),
		])
	else:
		var bf := UIKit.button("Mostra anche le regole fanmade")
		bf.custom_minimum_size = Vector2(0, 50)
		bf.pressed.connect(func(): fan_requested.emit())
		_body.add_child(bf)

# ---------- gadget ----------
func _gadgets() -> void:
	_h("Punti gadget")
	_t("""[b]La scorta.[/b] A inizio gara ogni navetta riceve una scorta di punti che dipende dalla lunghezza della pista (un punto ogni %d passi dalla partenza al traguardo, da 6 a 12), più o meno quelli della batteria scelta in officina. Non se ne ricevono altri: ogni punto speso è perso.

[b]La scelta segreta.[/b] All'inizio di ogni turno, prima di muovere, ognuno decide in segreto quali gadget usare, con [b]1 o 2 punti[/b] ciascuno, entro il tempo scelto nel menu (20, 30 o 60 secondi, o senza limite). Poi si muove come al solito e i gadget si scoprono quando agiscono. La navetta «Di serie» ha i 10 gadget originali; con le navette dell'officina puoi usare solo quelli che hai montato.

[b]Mezzi danni.[/b] Tutti i gadget fanno mezzo danno: ne servono due per un danno intero. Chi è invisibile non si può colpire con cecchini, missili, arpione e blast; le mine invece colpiscono tutti.""" % int(SledGame.BUDGET_DIV))
	var cols := {"Attacchi": Color("ff6a5a"), "Difese": Color("4fb8ff"), "Movimento": Color("e8b030")}
	for cat in SledGame.CATEGORIES:
		_h(String(cat).to_upper())
		var items := []
		for k in SledGame.GADGET_ORDER:
			if String(SledGame.GADGETS[k][1]) == cat:
				items.append(_gadget_card(k, cols[cat]))
		_grid(items)

func _gadget_card(k: String, col: Color) -> PanelContainer:
	var d: Array = GADGET_TEXT[k]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(col, 0.06), 14, Color(col, 0.0), 0, 6))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pc.add_child(h)
	var tex: Texture2D = main._gadget_tex(k)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var th := 118.0 if wide else 96.0
	var tw: float = th * (float(tex.get_width()) / float(tex.get_height())) if tex else 200.0
	tr.custom_minimum_size = Vector2(tw, th)
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := UIKit.label(String(SledGame.GADGETS[k][0]), 22, col.lightened(0.35))
	nm.add_theme_font_override("font", UIKit.font(UIKit.F_BOLD))
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(nm)
	var lv := "[b]1 punto:[/b] %s" % d[0]
	if SledGame.max_level(k) > 1:
		lv += "\n[b]2 punti:[/b] %s" % d[1]
	var r: RichTextLabel = main._rule_text(lv + "\n[color=#94a9c0]%s[/color]" % d[2])
	v.add_child(r)
	return pc

# ---------- officina ----------
func _shop() -> void:
	_h("Costruisci la tua navetta")
	_t("Dal menu, «Officina»: hai [b]%d crediti[/b] da spendere e un nome originale da dare. Il costo di ogni pezzo è scritto sul suo pulsante; i crediti che restano non servono a niente." % ShipBuild.CREDITS)
	_grid([
		_box(UIKit.HEAD, "Modello 3D", "Uno dei cinque modelli (Fenice rossa, Lama blu, Vespa gialla, Mantide verde, Ombra viola). È solo estetica."),
		_box(UIKit.HEAD, "Scafo", "Quanti danni reggi. Ogni danno è una carta inutile che occupa posto in mano. [b]Leggero[/b] (gratis): il 4° danno distrugge la navetta. [b]Medio[/b] (2 crediti): il 5°, come di serie. [b]Pesante[/b] (4 crediti): il primo danno non toglie carte e solo il 6° la distrugge."),
		_box(UIKit.HEAD, "Mazzo dei motori", "Le tue 20 carte da 1 a 5. [b]Economico[/b] (gratis): più carte basse, 5-5-4-3-3. [b]Bilanciato[/b] (1 credito): 4 per valore. [b]Turbo[/b] (4 crediti): più carte alte, 3-3-4-5-5."),
		_box(UIKit.HEAD, "Tipo di motori", "Come guidi. [b]Normali[/b] (gratis). Per 2 crediti: [b]stabili[/b] (a ogni mossa puoi derivare di una corsia in meno, se ti conviene), [b]agili[/b] (in curva troppo forte il primo danno è solo mezzo danno), [b]potenti[/b] (+1 alla velocità con i motori pari, ma con motori diversi derivi di 1 in più), [b]ionici[/b] (+1 punto gadget ogni 2 turni)."),
		_box(UIKit.HEAD, "Batteria", "I punti gadget di partenza. [b]Piccola[/b] (gratis): 3 punti in meno. [b]Media[/b] (2 crediti): la scorta normale. [b]Grande[/b] (4 crediti): 3 punti in più."),
		_box(UIKit.HEAD, "Gadget montati", "Ogni gadget costa 1 credito. Sono divisi in Attacchi, Difese e Movimento; in gara puoi usare solo quelli montati, e il pannello dei gadget mostra solo quelli."),
	])
	_h("Modelli, salvataggio e galleria")
	_t("""Ci sono modelli pronti (Predatore, Fortezza, Sprinter, Cecchino, Ionico) da cui partire e cambiare quello che vuoi. [b]Salva[/b] tiene la navetta su questo dispositivo; [b]Pubblica[/b] la mette nella [b]galleria online[/b], dove si prendono anche quelle degli altri.

Nella pagina Gara, sotto ogni colore, la tendina sceglie quale navetta corre (anche per i bot). Online e col telefono ognuno porta la sua, scegliendola quando entra nella stanza.""")

# ---------- stanze e varianti ----------
func _room() -> void:
	_h("Giocare insieme")
	_grid([
		_box(UIKit.HEAD, "Umano", "Si gioca su questo schermo, passandosi il dispositivo: tocca a chi è di turno."),
		_box(UIKit.HEAD, "Bot", "La navetta la guida il computer."),
		_box(UIKit.HEAD, "Online", "Un amico, da un altro dispositivo, entra nella tua stanza con il codice di 4 lettere (da «Entra in una stanza»)."),
		_box(UIKit.HEAD, "Telefono", "Come «Online», ma si entra inquadrando il QR: il telefono si apre già sulla stanza, scegli nome, navetta e colore e da lì giochi le carte e scegli la casella."),
	])
	_t("""[b]Creare la stanza.[/b] In «Gara» metti su «Online» o «Telefono» i posti per gli altri e premi «Crea la stanza»: nella sala d'attesa compaiono codice grande, QR e chi è già entrato. Se un solo colore è su «Umano», questo schermo gioca con quella navetta; se nessuno lo è, questo diventa uno [b]schermo condiviso[/b] (TV, computer, tablet) che mostra solo la pista e tutti giocano dal telefono. Quando ci siete tutti, premi «Inizia la gara»: i posti rimasti liberi li guida il computer.

Se esci o ti si spegne lo schermo, rientri con lo stesso nome (o dal codice) e la gara riprende dal punto in cui era.""")
	_h("Varianti")
	_t("""[b]Simultaneo.[/b] Tutti programmano la mossa (carte e casella d'arrivo) senza vedere quella degli altri, poi le navette partono insieme: chi ha più caselle da fare va più veloce. Due navette non entrano mai nella stessa casella nello stesso momento: se possono la evitano, altrimenti entra la più veloce (a parità, chi era più avanti) e l'altra si ferma prima con mezzo danno.

[b]Gran Tour.[/b] Più piste di fila con le stesse navette (solo su questo dispositivo). A ogni gara il primo prende tanti punti quante sono le navette meno una, poi a scalare; una navetta distrutta prende 0. Vince chi ha più punti alla fine.

[b]Pista casuale.[/b] Genera un percorso scegliendo difficoltà e lunghezza, con o senza segmenti fanmade. [b]Editor[/b]: disegni i tuoi percorsi, che compaiono in «Create da te» e si sincronizzano con la libreria online (parola segreta uguale su ogni dispositivo).""")

# ---------- comandi ----------
func _keys() -> void:
	_h("Tocco")
	_t("Un dito trascina la pista; due dita avvicinano, ruotano e, spostate insieme in su o in giù, inclinano la vista. Tocca un cerchio per la partenza, una carta e poi uno spazio della plancia, un anello per la destinazione.")
	_h("Mouse")
	_t("Rotellina per lo zoom, tasto destro per ruotare. «Segui» fa girare la telecamera con la navetta di turno.")
	_h("Tastiera")
	_t("[b]1–5[/b] sceglie una carta; [b]A[/b], [b]S[/b], [b]D[/b] (o le frecce) la mettono su motore sinistro, freno, motore destro; [b]Invio[/b] muove; [b]Backspace[/b] riprende le carte; [b]Esc[/b] torna indietro o apre il menu.")
