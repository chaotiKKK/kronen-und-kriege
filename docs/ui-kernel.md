# UiKernel-Zuschnitt

> Dokumentversion: 1.1
> Stand: 2026-11-06
> Status: Herrschaftsmodal vorhanden; UiKernel-Extraktion noch offen
> Gültig für Save-Schema: 3

## Problem

`Main.gd` ist derzeit gleichzeitig Composition Root, Layout-Bauer, Zustandsleser, Event-Modal, Picker, Stammbaum-Steuerung, Customizer und Zeitlauf. Das ist für den Prototyp tragbar, aber jede neue systemische Entscheidung würde weitere direkte Zugriffe auf `game` hinzufügen. `Game.gd` ist bereits die Regelinstanz; die UI darf nicht zu einer zweiten werden.

Der UiKernel ist **keine zweite Spielschicht**. Er besitzt nur flüchtigen UI-Zustand und übersetzt Nutzerabsichten in Kommandos an `Game.gd`.

## Zielbild

```text
Main.gd (Composition Root)
  ├─ UiKernel.gd
  │    ├─ SelectionState
  │    ├─ ModalStack
  │    ├─ CommandRouter
  │    └─ ViewModelBuilder
  ├─ Panels/ (reine Darstellung)
  │    ├─ TopBar
  │    ├─ ProvincePanel
  │    ├─ EventModal
  │    ├─ PickerModal
  │    └─ FamilyTreeOverlay
  ├─ MapView.gd / FamilyTree.gd (Projektionen)
  ├─ Game.gd (Regeln, autoritativer Zustand)
  └─ SaveGame.gd (Schema, Migration, Diff)
```

## Zuständigkeiten

| Modul | Darf | Darf nicht | Test |
|---|---|---|---|
| `Main.gd` | Szene aufbauen, `Game` erzeugen, Panels verdrahten, Signalverbindungen lösen | Regeln auswerten, Spielzustand direkt mutieren, Dateien lesen/schreiben | `HousePlayTest`, `CustomizeTest` |
| `UiKernel.gd` | Auswahl, Modalstapel, Kommando-Routing, Ergebnisweitergabe, UI-Signale | `houses`, `provinces`, `gold` oder `opinion` direkt schreiben; `FileAccess` benutzen | neuer `UiKernelTest` |
| `ViewModelBuilder` | Snapshot in Anzeigezeichenketten, Flags und deaktivierte Buttons übersetzen | Spielzustand verändern oder Zufall ziehen | `UiKernelTest` mit goldenen Strings |
| Panels | Signale senden, gerenderte Werte anzeigen | `game` halten, `Game`-Methoden aufrufen, Speichern auslösen | Panel-Smoke |
| `Game.gd` | Regeln, Kosten, Abklingzeiten, Zustandsübergänge, `snapshot()`/`restore()` | UI-Typen, `Control`, `FileAccess`, konkrete Button-Texte | `HouseTest`, `IntrigueTest`, `SaveMigrationTest` |
| `SaveGame.gd` | Schema, Migration, Validierung, kanonischer Diff | UI oder Regeln | `SaveMigrationTest` |

## Kommandovertrag

Jede Nutzerabsicht wird als ein Kommando mit stabiler ID geroutet. Die UI ruft nie `game.attack()` direkt aus einem Button-Callback auf.

```gdscript
# UiKernel.gd, Zielvertrag (Welle 1)
func dispatch(command: Dictionary) -> Dictionary:
    # command = {"id": "attack", "target": "alba", "source": "province_panel"}
    var result: Dictionary = _route(command)
    if bool(result.get("ok", false)):
        emit_signal("state_changed", result.get("refresh", []))
    return result
```

Rückgabe:

```gdscript
{
    "ok": true,
    "code": "ok",              # ok | blocked | invalid | not_owner | no_target
    "message": "Sieg bei Alba.",
    "delta": {"gold": -25, "prestige": 15, "owner": "alba"},
    "refresh": ["top_bar", "map", "province_panel"],
}
```

Regeln:

1. `code` ist maschinenlesbar; `message` ist bereits lokalisierte Anzeige.
2. `delta` nennt nur Größen, die sich tatsächlich geändert haben. Die UI berechnet keine Regelwirkung.
3. Ein blockiertes Kommando verändert keinen Spielzustand und erzeugt keinen Log-Eintrag im Spiel, nur optional einen UI-Hinweis.
4. `refresh` ist eine Liste von Panel-IDs, keine direkte Control-Referenz.
5. Der UiKernel darf einen Snapshot lesen, aber niemals einen eigenen Spielzustand daraus ableiten, der gespeichert wird.

## Kommando-IDs (Ist und Ziel)

| ID | Heute in `Main.gd` | Ziel | persistiert |
|---|---|---|---|
| `develop` | `game.develop(selected)` | `command.develop` | `provinces[].dev`, `gold` |
| `recruit` | `game.recruit(selected)` | `command.recruit` | `provinces[].levy`, `gold` |
| `attack` | `game.attack(selected)` | `command.attack` | `provinces[].owner`, `levy`, `prestige` |
| `court` | `game.court()` | `command.court` | `gold`, `prestige` |
| `marry` | `_pick("marry", target)` | `command.marry` | `spouse`, `opinion`, `gold` |
| `bed` | `game.bed()` | `command.bed` | `pregnant`, `cooldowns` |
| `seduce` | `game.seduce(target)` | `command.seduce` | `lover_house`, `opinion`, `scandal` |
| `murder` | `game.murder(target)` | `command.murder` | `ruler`, `opinion`, `prestige` |
| `kidnap` | `game.kidnap(target)` | `command.kidnap` | `captive`, `opinion` |
| `ransom` | `game.ransom_captive()` | `command.ransom` | `gold`, `captive`, `opinion` |
| `force_marry` | `game.force_marry_captive()` | `command.force_marry` | `spouse`, `captive`, `opinion` |
| `apply_event` | `_choose(index)` | `command.apply_event` | Ereigniswirkungen |
| `set_speed` | `_set_speed(value)` | `command.set_speed` | nur UI/`speed` |
| `save` | `_save()` | `command.save` | Datei |
| `load` | `_load()` | `command.load` | Datei |
| `council_assign` | `game.assign_council(office, index)` | `command.council_assign` | `council`, indirekt `levy` über H1 |
| `law_succession` | `game.set_law("succession", value)` | `command.law_succession` | `laws.succession`, `heir` über H2 |
| `build` | `game.build(id, key)` | `command.build` | `buildings`, `gold`, `levy` über H5 |

`save` und `load` sind Randkommandos: Sie dürfen `Game.snapshot()` und `Game.restore()` benutzen, aber nie eigenes JSON schreiben. Das Schema bleibt in `SaveGame.gd`.

## Modalstapel

Es gibt genau einen sichtbaren Modalzustand. `Escape` schließt den obersten Eintrag, danach wird der darunterliegende Zustand wiederhergestellt.

| Zustand | Öffner | Schließer | Darf Spielzustand ändern |
|---|---|---|---|
| `start` | `_show_start()` | Spielstart | nein |
| `new_game` | `_show_newgame()` | Zurück | nein |
| `create` | `_show_create()` | Zurück/Start | ja, nur beim Start |
| `customizer` | Porträt/Wappen | Abbrechen/Übernehmen | ja, nur nach Bestätigung |
| `picker` | Heiraten/Intrige | Ziel oder Zurück | nein |
| `event` | offenes Ereignis | Optionsknopf | ja, genau eine Option |
| `family_tree` | Stammbaum | Schließen | nein |
| `herrschaft` | Herrschaftsbutton | Schließen | ja, Rat, Gesetz und Bau über `Game`-Kommandos |
| `game_over` | Tod ohne Erben | Neues Spiel | nein |

Der Modalstapel ist UI-Zustand und wird **nicht** gespeichert. Nach `load` wird er auf `start`/`game` zurückgesetzt.

## Schrittweise Extraktion

| Schritt | Verschiebung | Verhaltensänderung | Gate |
|---|---|---|---|
| 1 | Kommando-IDs und `dispatch()`-Gerüst aus `Main.gd` herausziehen; bestehende Buttons rufen nur noch `dispatch` | keine | `HousePlayTest`, `IntrigueTest`, `CustomizeTest` |
| 2 | `EventModal` und `PickerModal` aus `_show_event`/`_open_picker` lösen | keine | dieselben Tests plus `SaveMigrationTest` |
| 3 | `ProvincePanel` und `TopBar` aus `refresh()` lösen; `ViewModelBuilder` liefert nur Strings/Flags | keine | `TouchTest`, `ShotTest` |
| 4 | `MapView` und `FamilyTree` erhalten Projektionen statt `game` | keine | `MapTest`, `ShotTest` |
| 5 | `UiKernelTest` prüft blockierte Kommandos, Modalstapel und Save-Grenze | keine | alle Suiten |

Nach jedem Schritt gilt: `Game.gd` bleibt autoritativ, `snapshot()`/`restore()` bleiben unverändert, und der Save-Test läuft.

## Anti-Ziele

- Kein reaktives Framework und kein generischer State-Store. Godot-Signale und explizite Kommandos reichen.
- Keine UI-Logik in `Game.gd`, keine Regel-Logik in Panels.
- Kein Speichern von UI-Zustand (Auswahl, offene Modals, Button-Fokus) im Spielstand.
- Kein direktes `game.houses[...] = ...` aus einem Panel. Ausnahmen sind nur Leseoperationen.
- Keine vorzeitige Aufteilung von `Game.gd` in viele Manager, solange die Kanten nicht durch Tests belegt sind.

## Status Welle 1

Die Grenze ist dokumentiert und `SaveGame.gd` ist ausgelagert. Das neue Modal „Herrschaft“ ruft für Rat, Erbfolge und Bau bereits ausschließlich `Game`-Methoden auf; der Spielzustand bleibt dort autoritativ. Die formale `UiKernel`-Klasse mit `dispatch()` existiert noch nicht, deshalb bleiben die Aufrufe in `Main.gd`. `Main._load()` prüft weiterhin den Rückgabewert von `Game.restore()` und bricht bei einem ungültigen Stand sichtbar ab.

Das Modal ist durch den Script-Parse-Check und den Windows-Export abgedeckt; ein eigener Headless-UI-Test für die Knöpfe existiert noch nicht.
