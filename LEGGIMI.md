# Ion Tails — corsa di navette nei canyon

Versione fantascientifica di **Snow Tails**: al posto della slitta trainata dai cani c'è una navetta,
un abitacolo trainato da **due motori affiancati** (stesso meccanismo: motore sinistro + motore destro
− freno, deriva verso il motore più forte). La pista è rifatta come il fondo di un canyon desertico,
con le **pareti del canyon in 3D** ai lati e i **nidi dei cecchini** sul ciglio.

Gioco online: https://tannoiser2.github.io/Ion-Tails/ (stanze Firebase sotto `iontails/rooms`).

Progetto Godot 4.7, renderer Compatibility. Le tessere sono le scansioni di Snow Tails ricolorate
(`tools/recolor_tiles.py`): uso personale, da non distribuire.

## Regole aggiuntive: punti gadget
A inizio gara ogni navetta riceve una **scorta di punti** in base alla lunghezza della pista: un punto
ogni 4 passi dalla partenza al traguardo, al massimo 12 (The Nutcracker 11, Bruce's Nightmare 12). Non se ne ricevono altri.

All'inizio di ogni **turno** (tutte le navette muovono una volta) ognuno sceglie **in segreto** i gadget:
per ognuno ci sono due tasti, **1** e **2** punti; se ne accende al massimo uno, toccando quello acceso
si spegne. C'è un **conto alla rovescia** scelto nel menu (20, 30, 60 secondi o senza limite; allo
scadere vale la scelta fatta fin lì). Online e con i telefoni scelgono tutti nello stesso momento;
sullo stesso dispositivo uno alla volta dietro la copertina. Poi si muove come in Snow Tails; i gadget
si scoprono solo quando agiscono.

**Tutti i gadget fanno mezzo danno**: ne servono due per un danno intero (5 danni = navetta distrutta).

| Categoria | Gadget | 1 punto | 2 punti |
|---|---|---|---|
| Attacchi | Cecchino (bersaglio a scelta, spara a fine mossa del bersaglio) | mira 55% | mira 80% |
| Attacchi | Mine (sulle caselle lasciate dietro) | 1 mina | 2 mine |
| Attacchi | Missile (dritto nella tua corsia, a fine mossa) | gittata 7 | gittata 10 |
| Difese | Scudo (bolla azzurra da quando la navetta parte) | −40% alla mira dei cecchini, ferma i missili il 20% delle volte | −80%, 40% |
| Difese | Radar (onda verde e conteggio a inizio turno) | mine fino a 12 caselle davanti | fino a 24 |
| Difese | CME (contro i missili) | il missile cambia corsia | il missile esplode |
| Difese | Invisibilità | 1 turno | 2 turni |
| Movimento | Postbruciatore | +1 velocità | +2 velocità |
| Movimento | Arpione (navetta più vicina davanti, fino a 6 passi) | −1 velocità | −2 velocità |
| Movimento | Blast ionico (navetta più vicina davanti, fino a 3 passi) | 1 corsia verso il bordo | 2 corsie |

Mira del cecchino: −4% per ogni punto di velocità del bersaglio oltre 4, −8% per ogni corsia fra il
bersaglio e la parete del canyon. **Invisibilità**: la navetta sparisce agli altri (chi la guida vede una
sagoma trasparente); cecchini, missili, arpione e blast non la trovano, ma lei può sganciare mine e
sparare; le mine colpiscono anche chi è invisibile.

Fuori dalle caselle il terreno è una **banchina di roccia rialzata** che continua nelle pareti del canyon:
dove la pista si restringe la roccia avanza a sperone (`SegmentFx.terrain`).

Ogni curva con limite ha una **barriera elettrificata** da un bordo all'altro della pista con il
numero del limite olografico che ruota a mezz'aria.

La CPU sceglie i gadget guardando la pista: missili solo con un bersaglio davanti nella propria
corsia, mine con qualcuno dietro, blast e arpione su chi è subito davanti, scudo e CME quando è
minacciata, radar se ci sono mine altrui.

Il resto è Snow Tails: carte 1-5, motori a 3 all'inizio, curve con limite, bordi, tamponamenti,
massi, dune e crepacci, salto della gola. Nei segmenti fanmade il vento diventa **tempesta di sabbia**,
la neve fresca **sabbia**, il ghiaccio **vetro** e la baita un'**officina**.

## Token dei gadget ed esiti
I riquadri dei gadget nel pannello sono i token disegnati (`assets/gadgets/<chiave>.webp`, tagliati
dal foglio con tutti i token); quello scelto si accende. Ogni effetto ha un avviso sulla pista: scritta
che sale (COLPITA, MANCATA, SCUDO, MINA!, MISSILE A SEGNO, CME: DEVIATO / ESPLOSO, BLAST, ARPIONE,
POSTBRUCIATORE, INVISIBILE), piccola esplosione quando un colpo va a segno, bolla traslucida dello
scudo quando para un colpo.

## Navette
I modelli sono i 5 GLB fatti con Meshy (`Desktop/Ludoteca/Ion Tails`), ridotti a 30.000 triangoli con
texture 1024 e raddrizzati (`tools/navette_glb.py`): `assets/models/ship_<colore>.glb`, con le posizioni
degli ugelli in `ships.json`. La fiamma dietro ogni motore segue la carta giocata su quel motore: corta
con l'1, lunga e intensa con il 5. Nel replay si rivedono tutti gli effetti dei gadget.

### Dove sta nel codice
- `scripts/game.gd`, sezione «Ion Tails: punti gadget»: scorta (`budget_for`), scelta (`apply_alloc`),
  arpione (`apply_hooks`), mira dei cecchini (`sniper_chance`), missile (`_missile`), effetti a fine
  mossa (`_gadgets_after_move`), scelte della CPU (`ai_alloc`).
- `scripts/main.gd`: fase dei gadget (`_energy_next`, `_energy_panel`, `_energy_round_online` per le scelte
  online in parallelo) ed effetti visivi (`_play_gadget_fx`). Online ogni scelta è una mossa del registro
  (`{"k": "en", "a": {"sn": 2, "snt": 1, ...}}`).
- `scripts/team_model.gd`: la navetta (costruita in codice). `scripts/segment_fx.gd`: canyon a strati,
  nidi dei cecchini, pinnacoli. `scripts/board_view_3d.gd`: laser, missili, mine, esplosioni, blast ionico, scudi.

## Grafica
- Carte spinta 1-5 per colore, carta danno, gettoni freno, plance: `tools/build_ion_art.py`.
- Tessere: `python3 tools/recolor_tiles.py <originali di Snow Tails> assets/tiles`.
- Copertina e icona: rendering della partenza (`tests/ion_cover.gd`) con il titolo sopra.
- Font: Orbitron (titoli) ed Exo 2 (testo), licenza OFL. `python3 tools/controlla_glifi.py` controlla
  che ogni carattere delle scritte esista nei font.

## Prove
- `tests/energy_ai.gd`: gare senza grafica con sole CPU e gadget.
- `tests/sim_cpu.gd`: gara con la scena vera (anche simultanea con `ST_SIM=1`).
- `tests/ion_shots.gd`: screenshot di menu, scelta dei gadget, mossa e colpi dei cecchini.
- `tests/online_play.gd` con `tests/firebase_mock.py`: due istanze giocano una gara online
  (usare `ST_SESSION` diverso per le due istanze) e le impronte finali devono coincidere.

## Online
Come Snow Tails: «Crea una stanza», «Schermo condiviso: si gioca col telefono» (QR con l'indirizzo
`…/Ion-Tails/?r=CODICE`), rientro con lo stesso codice. Le stanze usano la regola generica `$game`
del progetto Firebase; per la **libreria online delle piste** serve il blocco `iontails` di
`firebase/database.rules.json`.

## Pubblicazione
Il workflow `pages.yml` parte solo a mano (Actions → «Run workflow») o con un commit su `main`
che contiene `[pubblica]` nel messaggio.

## Mappare curve e inversioni
Rettilinei, partenza e arrivo sono griglie regolari e sono già mappati.
Sulle curve non ci sono corsie fisse: ogni tessera è una **rete di caselle**.

1. Menu → «Mappa le tessere», scegli la faccia (• = da mappare, ✓ = fatta).
2. Modalità **Catena**: tocca le caselle una dopo l'altra nel senso di marcia,
   dalla freccia verde (ingresso) verso la rossa (uscita). Ogni passo va nella
   casella **davanti**, quella che ha un lato in comune oltre una linea blu.
   Toccando vicino a un puntino grigio ci si aggancia al centro riconosciuto.
3. Tocca due volte la stessa casella (o «Nuova catena») per chiudere la catena e
   iniziarne un'altra. Le catene possono incrociarsi e condividere caselle:
   copri tutte le caselle, comprese quelle in più all'esterno della curva.
4. **Derive**: mostra le diagonali calcolate dal gioco (blu = a sinistra, viola =
   a destra). La deriva va avanti in diagonale oltre una linea nera, anche quando
   la casella tocca la tua solo nello spigolo. Controlla che le frecce tratteggiate
   siano quelle che useresti al tavolo.
5. **Cancella** toglie una casella (o un collegamento toccando il centro della freccia);
   **Annulla** torna indietro; **Salva** scrive la faccia.

Per The Nutcracker servono **Curva a sinistra (p.7)** e **Inversione a destra (p.2)**.
**Editor delle tessere.** Tre modalità, sempre con due tocchi:
- «Avanti»: tocca la casella di partenza e poi quella davanti; se il passo in avanti c'è
  sparisce, se non c'è compare.
- «Deriva»: lo stesso per le diagonali (blu = a sinistra, viola = a destra). La freccia
  punta sempre verso la seconda casella toccata; se c'era la diagonale al contrario, viene
  girata.
- «Caselle»: un punto vuoto aggiunge una casella, una casella esistente viene tolta con i
  suoi collegamenti.
«Mostra avanti» e «Mostra derive» accendono e spengono le frecce; «Annulla» torna indietro
di un passo. Sotto: Salva, Incorpora nel progetto, Ripristina originale, Apri cartella.

**Dove finiscono le correzioni.** Si salvano sempre nella cartella dati utente di Godot
(`user://faces/`), fuori dal progetto, e hanno la precedenza sulle facce del progetto:
aggiornare o sostituire il progetto non le cancella. Contengono solo la rete corretta e il
punto d'ingresso della tessera, così restano allineate anche se le immagini vengono rifatte.
- macOS: `~/Library/Application Support/Godot/app_userdata/Snow Tails - versione digitale (uso personale)/faces/`
- Windows: `%APPDATA%\Godot\app_userdata\Snow Tails - versione digitale (uso personale)\faces\`
- Linux: `~/.local/share/godot/app_userdata/Snow Tails - versione digitale (uso personale)/faces/`
Nell'editor: «Incorpora nel progetto» scrive la faccia corretta in `data/faces/` (solo
avviando il gioco dall'editor di Godot): da quel momento è la versione di base, inclusa
nelle esportazioni per iPhone e iPad. «Apri cartella correzioni» apre la cartella;
«Ripristina originale» cancella la correzione di quella faccia.
Le tue correzioni di p.1, p.2, p.7 e p.8 sono già incorporate; una copia sta in
`tools/corrections/` e `tools/apply_corrections.py` le riapplica se le facce vengono rigenerate. Le facce corrette hanno il simbolo ✎ nell'elenco.
Una mappatura vecchia (anche nel formato a corsie) copiata in quella cartella viene letta.

## Percorsi
In `data/courses/` ci sono i sette percorsi del regolamento: The Nutcracker,
The Hobbit's Breakfast, Yquem Inspired, Treemendous, The Riddler, Bruce's Nightmare,
Dagger of the Mountain Troll, più il Rettilineo di prova (con alberelli e cumulo di neve,
giocabile subito). Le sequenze sono ricavate dai disegni delle pp.10-11: controllale sul
tavolo e correggi l'elenco se serve.

Per giocarli vanno mappate quattro facce: **Curva a sinistra (p.7)**, **Curva a destra
(p.8)**, **Inversione a sinistra (p.1)** e **Inversione a destra (p.2)**. Tutti i percorsi
usano queste quattro.

Regole di montaggio: bandierine gialle sempre a sinistra e rosse a destra (i rettilinei
si percorrono di conseguenza); la partenza va con la posizione 1 all'interno della prima
curva: `start_p21` se la prima curva è a sinistra, `start_p22` se è a destra.

Facce disponibili:
- partenza/arrivo: `start_p21`, `start_p22`, `finish_p21`, `finish_p22`
- rettilinei: `straight_p13a`, `p14a`, `p14b`, `p16a`, `p16b`, `p18a`, `p18b`, `p19b`, `p20a`, `p20b`
- alberelli: `saplings_p13b`, `saplings_p17a`
- cumulo di neve: `snowdrift_p15a`, `snowdrift_p15b`
- crepaccio: `chasm_p17b`, `chasm_p19a`
- curve e inversioni: `corner_L_p07`, `corner_R_p08`, `uturn_L_p01`, `uturn_R_p02`

Tessere speciali: sul cumulo e sul crepaccio le caselle impraticabili non esistono, quindi
entrarci è come urtare il bordo (la deriva in diagonale fra caselle libere resta possibile).
Gli alberelli: chi li colpisce prende un'ammaccatura, l'alberello viene tolto e il movimento
continua. Le caselle bloccate le ho lette dalle scansioni: se qualcosa non torna, le facce si
possono correggere nell'editor come le altre.

## Anteprima dei percorsi
Nella barra di stato, il riquadro «Percorsi» (sotto le ammaccature) accende o spegne
l'anteprima: mentre metti le carte sulla plancia, prima di muovere, la pista mostra tutti i
percorsi possibili nel colore della tua slitta, come linee: i passi in avanti sono sottili,
i passi di deriva (in diagonale) più spessi, più chiari e bordati di bianco; poi le caselle
d'arrivo e le eventuali ammaccature (−n). La telecamera inquadra i percorsi. L'impostazione resta per tutta la partita.

## Incidenti
- Alberello travolto: cade nella direzione della slitta in una nuvola di neve e sparisce
  (si può sempre passare: costa un'ammaccatura, come da regolamento).
- Urto contro il bordo o contro un'altra slitta: nuvola di neve nel punto dell'urto e le
  slitte coinvolte sobbalzano.
- Curva presa troppo forte o salto troppo lento: piccola sbandata nella neve.
Gli stessi effetti compaiono nel replay.

## Replay
Alla fine della gara, «Rivedi la gara» riproduce tutti i giri con le mosse in contemporanea:
in ogni giro tutte le slitte partono insieme dalla casella in cui erano e arrivano insieme
alla casella d'arrivo, a velocità costante, quindi chi ha fatto più strada va più veloce;
il giro successivo parte subito, senza pause. Ammaccature, slitte distrutte e alberelli
travolti si aggiornano al passaggio da un giro all'altro. Pausa, velocità ×1/×2/×4,
Esc o «Esci dal replay» per tornare alla classifica.

## Editor dei percorsi
Dal menu, «Crea percorso» apre l'editor: a destra scegli i pezzi (partenza con il 1° a
sinistra o a destra, rettilinei, alberelli, cumulo, crepaccio, Leap of Death, curve,
inversioni, arrivo), a sinistra la pista cresce. Toccando un pezzo nella sequenza, i nuovi
pezzi si inseriscono dopo di lui, oppure lo togli con «Togli selezionato». «Parti da» carica
un percorso esistente da modificare. I pezzi che si sovrappongono diventano rossi; il
riepilogo conta rettilinei, curve e inversioni rispetto alla scatola. «Salva percorso»
controlla che la pista sia valida (partenza, arrivo con un rettilineo dopo, traguardo
raggiungibile) e la salva nella cartella dati (`user://courses/`): compare nel menu con ✎.

## Pista casuale
Nel menu, «Pista casuale» crea un percorso scegliendo solo difficoltà (bassa, media, alta)
e lunghezza (corta, media, lunga); «Genera un'altra pista» ne crea una nuova.
Il generatore rispetta i pezzi della scatola (al massimo 8 rettilinei comprese le facce
speciali, 4 curve, 2 inversioni, una Leap of Death), posa davvero le tessere scartando le
piste che si sovrappongono, e controlla che il traguardo sia raggiungibile.
Con la difficoltà crescono curve e inversioni e le tessere speciali (bassa: alberelli;
media: anche cumuli; alta: anche crepacci e Leap of Death), mentre diminuiscono i rettilinei
fra una svolta e l'altra.

## Regole implementate
Mazzo da 20 carte (quattro per valore 1–5), mano di 5; 1–3 carte dello stesso valore
su cane sinistro / freno / cane destro; velocità = cani − freno; deriva verso il cane più
forte, nei passi scelti; bonus di equilibrio pari alla posizione (non al primo turno);
ammaccature per curve oltre il limite (bonus compreso), bordo, tamponamento senza
pesca; quinta ammaccatura = slitta distrutta; partenza 4ª e 5ª con 1 e 2 carte extra;
ordine di gioco per posizione, a pari livello avanti chi è all'interno della prossima curva;
la gara continua finché tutte le slitte rimaste hanno tagliato il traguardo (chi arriva
smette di muovere e non ostacola più gli altri); in classifica conta prima il giro in cui si
taglia il traguardo, poi, a parità di giro, chi è andato più lontano oltre la linea.

Limiti letti sui cartelli delle scansioni: curve 4, inversioni 3.

## Variante simultanea (personale)
Nel menu, «Movimento: Simultaneo». A ogni giro tutti programmano la mossa (carte e casella
d'arrivo): le CPU subito, le persone una alla volta, con una copertina fra l'una e l'altra
se sullo stesso dispositivo ce n'è più d'una. Poi le slitte partono e arrivano insieme, in
modo fluido: chi ha più caselle da fare va più veloce (entra nella casella k al tempo k/n).
Due slitte non stanno mai nella stessa casella nello stesso momento. Si decide in
quest'ordine: chi resta ferma, poi chi va più veloce, a parità chi era più avanti a inizio
giro. Ognuna, se può, prende una rotta equivalente (stesso arrivo, stessa velocità, non più
ammaccature) che evita il contatto; se non può, si ferma prima e prende mezza ammaccatura
(due mezze fanno un'ammaccatura) e pesca normalmente. Gli alberelli li travolge chi ci passa
per primo. Funziona anche online e con lo schermo condiviso: ogni slitta ha il suo numero di
mossa nel giro (`k: "prog"`), chi ha creato la stanza scrive quelle delle CPU e di chi non risponde,
e quando ci sono tutte ogni dispositivo risolve il giro allo stesso modo.

## Come funziona il movimento
Ogni passo è «avanti» (un collegamento della rete) oppure «deriva» (una diagonale
calcolata: circa una casella avanti e una corsia di lato rispetto alla direzione di
marcia locale). Dove la rete offre più caselle il gioco le esplora tutte e mostra ogni
arrivo possibile.

## Test senza grafica
    godot --headless --path . -s res://tests/run_ai.gd -- res://data/courses/prova.json
    godot --headless --path . -s res://tests/sim_ai.gd      # variante simultanea, sole CPU

## Non ancora fatto
- Le altre facce delle curve (pp.3-6, 9-12): i percorsi usano solo p.1, 2, 7, 8.
- Editor di percorsi dentro il gioco, stagione a punti.

`tools/build_faces.py` è lo script Python che ha estratto le facce dalle scansioni.

## Font
Titoli e pulsanti principali: Luckiest Guy (Apache 2.0). Testo: Nunito (SIL Open Font
License). Simboli (frecce, stella, spunta, matita…): Noto Sans Symbols 2 e Noto Sans Math
(SIL Open Font License), usati come ripiego: nel browser, iPad compreso, non ci sono i font
di sistema. Le licenze sono in `assets/fonts/`.

Sui tablet e sui telefoni, nel browser, toccando un campo di testo (nome della pista, nome e
codice per l'online) si apre la finestra di inserimento del sistema con la sua tastiera.

## Caratteristiche fanmade
La pista corre su un argine di neve con i declivi ai lati e qualche abete sui pendii
(terreno generato attorno alle caselle, vale per tutte le piste).

Ai **rettilinei** (anche con alberelli, cumulo, crepaccio) si possono **sommare** queste
caratteristiche, nell'editor o nella pista casuale:
- **Salita**: chi parte da una tessera in salita ha 3 punti di velocità in meno (come un freno in più).
- **Discesa**: chi parte in discesa guadagna 1 punto ogni 3 (3 → 4, 6 → 8, 9 → 12).
- **Vento**: forza 1, 2 o 3 (`wind_force`; 0 = tirata a sorte a inizio gara). Di lato (←/→): chi
  parte dalla tessera ha tanta deriva in più nel verso del vento (sommata a quella dei cani);
  a favore (`F`): tanta velocità in più; contrario (`C`): tanta in meno.
- **Ghiaccio**: chi entra derivando continua a derivare; a fine movimento si scivola avanti
  di una casella.
- **Neve fresca**: le caselle coi cumuli costano 2 punti; la prima slitta che ci passa li spazza via. I cumuli (da 5 a 8) cambiano posto a ogni gara (`Course.randomize_def`).
- **Baita**: chi si ferma sulla casella accanto ripara metà dei danni (arrotondando a suo favore), ma non pesca.

Nel file del percorso un pezzo con caratteristiche si scrive così:
`{"id": "straight_p14a", "mods": {"slope": "up", "wind": "R", "ice": true}}`.
Il gioco stende sopra la tessera i livelli dipinti (`assets/fan/`, creati da
`tools/make_fan_tiles.py`), i cartelli all'ingresso (uno per caratteristica) e gli effetti 3D.

Il **bivio** è una tessera a sé (`fan_fork`): un'isola di abeti chiude la corsia di mezzo;
il corridoio di sinistra ha 4 caselle lunghe (scorciatoia, con un po' di neve fresca), quello
di destra 6 caselle normali.

Editor: tavolozza compatta, anteprima 3D (si ruota e si avvicina come in partita), pannello
delle caratteristiche quando è selezionato un rettilineo. Menu: «Dalla lista» o «Pista
casuale» con difficoltà, lunghezza e fanmade sì/no.
Test: `tests/fan_rules.gd`, `tests/gen_fan.gd`, `tests/gen_play_fan.gd`.

### CPU
La CPU non è addestrata: prova tutte le mosse possibili con le regole vere e dà un
punteggio. Per le 6 mosse migliori simula anche il turno dopo con le carte che restano
(così valuta salite, discese, vento e ghiaccio), e guarda il vento e la neve davanti.
`tests/ai_duel.gd` la fa correre contro la versione precedente: su 150 piste casuali
fanmade vince 101 gare contro 49; sulle piste normali posizione media 2,31 contro 2,69.
