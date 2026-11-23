# Scava Catacomba

Gioco in prima persona, 3D dark fantasy, fatto con **Godot 4.7**.
Sei sepolto in una catacomba piena di terra: la scavi, la porti al montacarichi,
la vendi e con le monete compri attrezzi migliori, fino a liberare tutta la catacomba
e trovare l'uscita nella stanza finale.

> **Stato:** prototipo. Sono pronte le fasi 0–2 (terreno scavabile, feedback dello scavo,
> ciclo base zaino → montacarichi → vendita → negozio).

![Screenshot](shot.png)

## Caratteristiche

- **Terra come massa continua**, non a blocchi: si consuma attorno al punto mirato
  (campo di densità + mesh *surface nets*, ricalcolata a chunk mentre scavi).
- **Tre tipi di terreno**: terra, terra dura (serve la pala) e roccia (serve il piccone).
  La pietra di stanze e corridoi non si scava.
- **Feedback dello scavo**: schegge, suoni generati via codice, scossa della camera
  e animazione dell'attrezzo in mano.
- **Ciclo di gioco**: zaino a secchi, pila sul montacarichi con bonus ogni 10 secchi,
  leva per mandarla su e venderla, negozio con pala, zaino più grande e piccone.
- **Niente crolli, niente mostri.** In futuro: ossa e scheletri che si usurano e si riparano.

## Comandi

| Tasto | Azione |
|---|---|
| `W` `A` `S` `D` | Muoversi |
| Mouse | Guardarsi intorno |
| Tasto sinistro (tenuto) | Scavare |
| `Spazio` | Saltare |
| `E` | Interagire (montacarichi, leva, negozio) / chiudere il negozio |
| `1` `2` `3` | Mani, pala, piccone (se comprati) |
| `Esc` | Liberare il mouse / chiudere il negozio |

## Come avviarlo

1. Scarica [Godot 4.7](https://godotengine.org/download) (versione standard, non .NET).
2. Clona il repository e apri `project.godot` con Godot.
3. Premi **F5** (scena principale: `scenes/main.tscn`).

Da riga di comando:

```
godot --path .
```

### Prove automatiche

```
godot --path . -- --loop    # prova il ciclo zaino -> pila -> vendita -> negozio
godot --path . -- --bench   # scava da solo 6 s, salva le misure in bench.txt e uno screenshot in shot.png
```

## Struttura del progetto

```
scenes/
  main.tscn          scena principale: Catacomba, Soffitto, Terra, Spawn, Player, HUD
  player.tscn        giocatore, camera, attrezzi in mano, suoni, schegge
  hud.tscn           interfaccia e negozio
  pezzi/             un pezzo per ogni modello del Modular Cave Kit (modello + collisione + volume di terra)
scripts/
  terrain.gd         terreno scavabile (densità, surface nets, chunk) — @tool, anteprima nell'editor
  player.gd          movimento, mira, scavo, interazioni
  viewmodel.gd       animazione dell'attrezzo in mano
  dig_sfx.gd         suoni dello scavo
  game_state.gd      monete, zaino, pila, negozio
  spawn_room.gd      arredo dello spawn: montacarichi, leva, negozio
  hud.gd             interfaccia
  main.gd            collega tutto + prove automatiche
tools/
  build_scenes.gd    rigenera le scene da codice
audio/               suoni provvisori generati
assetpack/           modelli 3D (Kenney, CC0)
```

## Modificare la catacomba

Stanze e corridoi sono i pezzi in `scenes/pezzi/`, figli del nodo **Catacomba** in `main.tscn`.

1. Trascina un pezzo dentro **Catacomba**, allineato alla griglia da 4 m (pavimento a `y = 2`).
2. Seleziona il nodo **Terra** e premi **Rigenera terra** nell'Inspector: il pezzo si riempie di terra.
3. Per lasciare un pezzo vuoto, imposta il suo meta `terra` a `false`.

> ⚠️ `tools/build_scenes.gd` rigenera le scene da zero e **sovrascrive le modifiche fatte a mano**:
> usalo solo se vuoi ripartire dalla pianta definita nello script.
>
> ```
> godot --headless --path . --script res://tools/build_scenes.gd
> ```

## Prossime fasi

3. Ossa e primo scheletro
4. Materiali e progressione (usura e riparazione degli scheletri)
5. Prima zona completa

## Crediti

Modelli 3D di [Kenney](https://www.kenney.nl) — licenza **CC0**:
[Modular Cave Kit](https://kenney.nl/assets/modular-cave-kit),
[Mini Dungeon](https://kenney.nl/assets/mini-dungeon),
[Graveyard Kit](https://kenney.nl/assets/graveyard-kit).
