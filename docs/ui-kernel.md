# UiKernel-Zuschnitt

> Dokumentversion: 1.3
> Stand: 2026-11-06
> Status: UiKernel-Extraktion abgeschlossen
> Gültig für Save-Schema: 4

## Problem

`Main.gd` war gleichzeitig Composition Root, Layout-Bauer, Zustandsleser, Event-Modal, Picker, Stammbaum-Steuerung, Customizer und Zeitlauf. Jede neue systemische Entscheidung hätte weitere direkte Zugriffe auf `game` hinzugefügt. `Game.gd` ist die Regelinstanz; die UI darf nicht zu einer zweiten werden.

Der UiKernel ist **keine zweite Spielschicht**. Er besitzt nur flüchtigen UI-Zustand und übersetzt Nutzerabsichten in Kommandos an `Game.gd`.

## Ist-Aufbau nach der Extraktion

```text
Main.gd (Composition Root + Renderer)
  ├─ UiKernel.gd
  │    ├─ SelectionState  (selection)
  │    ├─ ModalStack      (modal_stack, push/pop/top)
  │    └─ CommandRouter   (dispatch/_route, Handler für save/load)
  ├─ ViewModelBuilder.gd  (reine Anzeigezeichenketten und Flags)
  ├─ MapView.gd / FamilyTree.gd (Projektionen; erhalten weiterhin game)
  ├─ Game.gd (Regeln, autoritativer Zustand)
  └─ SaveGame.gd (Schema, Migration, Diff)
```

Die Panels sind weiterhin in `Main.gd` aufgebaut. Die in einer früheren Ausbaustufe angedachte Auslagerung einzelner Panel-Klassen ist **nicht** Teil dieser Extraktion; die sichtbare Oberfläche und ihre Signale bleiben unverändert.

## Zuständigkeiten

| Modul | Darf | Darf nicht | Test |
|---|---|---|---|
| `Main.gd` | Szene aufbauen, `Game` erzeugen, Panels rendern, Signale verdrahten, Save/Load als Randkommando ausführen, Customizer-Snapshot übernehmen | Regeln auswerten, Spielzustand aus Button-Callbacks direkt mutieren | `HousePlayTest`, `CustomizeTest` |
| `UiKernel.gd` | Auswahl, Modalstapel, Kommando-Routing, Ergebnisweitergabe, `game.speed` als UI-Zeitlauf setzen | `houses`, `provinces`, `gold` oder `opinion` direkt schreiben; `FileAccess` benutzen | `UiKernelTest` |
| `ViewModelBuilder` | Snapshot in Anzeigezeichenketten, Flags und deaktivierte Buttons übersetzen | Spielzustand verändern oder Zufall ziehen | `UiKernelTest` mit goldenen Strings |
| `MapView.gd`, `FamilyTree.gd` | Den aktuellen Spielstand lesen und projizieren | Regeln verändern | `MapTest`, `ShotTest` |
| `Game.gd` | Regeln, Kosten, Abklingzeiten, Zustandsübergänge, `snapshot()`/`restore()` | UI-Typen, `Control`, `FileAccess`, konkrete Button-Texte | `HouseTest`, `IntrigueTest`, `SaveMigrationTest` |
| `SaveGame.gd` | Schema, Migration, Validierung, kanonischer Diff | UI oder Regeln | `SaveMigrationTest` |

## Kommandovertrag

Jede Nutzerabsicht wird als ein Kommando mit stabiler ID geroutet. Die UI ruft nie `game.attack()` direkt aus einem Button-Callback auf.

```gdscript
# UiKernel.gd
func dispatch(command: Dictionary) -> Dictionary:
    # command = {"id": "attack", "target": "alba", "source": "province_panel"}
    var result: Dictionary = _route(...)
    if bool(result.get("ok", false)):
        state_changed.emit(result.get("refresh", []))
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
6. `save` und `load` werden an Handler in `Main.gd` delegiert; der Kernel öffnet selbst keine Datei.

## Kommando-IDs (umgesetzt)

| ID | Aufruf nach der Extraktion | Autoritative Methode | persistiert |
|---|---|---|---|
| `develop` | `kernel.dispatch({"id":"develop"})` | `game.develop(selection)` | `provinces[].dev`, `gold` |
| `recruit` | `kernel.dispatch({"id":"recruit"})` | `game.recruit(selection)` | `provinces[].levy`, `gold` |
| `attack` | `kernel.dispatch({"id":"attack"})` | `game.attack(selection)` | `provinces[].owner`, `levy`, `prestige` |
| `court` | `kernel.dispatch({"id":"court"})` | `game.court()` | `gold`, `prestige` |
| `marry` | `_pick("marry", target)` → `kernel.dispatch` | `game.do_action("marry", target)` | `spouse`, `opinion`, `gold` |
| `bed` | `kernel.dispatch({"id":"bed"})` | `game.bed()` | `pregnant`, `cooldowns` |
| `seduce` | `_pick("seduce", target)` → `kernel.dispatch` | `game.do_action("seduce", target)` | `lover_house`, `opinion`, `scandal` |
| `murder` | `_pick("murder", target)` → `kernel.dispatch` | `game.do_action("murder", target)` | `ruler`, `opinion`, `prestige` |
| `kidnap` | `_pick("kidnap", target)` → `kernel.dispatch` | `game.do_action("kidnap", target)` | `captive`, `opinion` |
| `ransom` | `kernel.dispatch({"id":"ransom"})` | `game.ransom_captive()` | `gold`, `captive`, `opinion` |
| `force_marry` | `kernel.dispatch({"id":"force_marry"})` | `game.force_marry_captive()` | `spouse`, `captive`, `opinion` |
| `apply_event` | `_choose(index)` → `kernel.dispatch` | `game.apply_event(option)` | Ereigniswirkungen |
| `set_speed` | `_set_speed(value)` → `kernel.dispatch` | `game.speed = value` | nur UI/`speed` |
| `save` | `kernel.dispatch({"id":"save"})` | `Main._save()` über Handler | Datei |
| `load` | `kernel.dispatch({"id":"load"})` | `Main._load()` über Handler | Datei |
| `council_assign` | `_cycle_council(office)` → `kernel.dispatch` | `game.assign_council(office, index)` | `council`, indirekt `levy` über H1 |
| `law_succession` | `_toggle_succession()` → `kernel.dispatch` | `game.set_law("succession", value)` | `laws.succession`, `heir` über H2 |
| `build` | `_build_system(key)` → `kernel.dispatch` | `game.build(selection, key)` | `buildings`, `gold`, `levy`/`defense` über H5 |
| `set_tax` | `_toggle_tax()` → `kernel.dispatch` | `game.set_law("tax", value)` | `laws.tax`, indirekt `gold` über H3 |
| `claim` | `_fabricate_claim()` → `kernel.dispatch` | `game.fabricate_claim(selection)` | `claims`, `gold` |
| `army` | `_raise_army()` → `kernel.dispatch` | `game.raise_army(selection)` | `armies`, `gold` |
| `siege` | `_advance_siege()` → `kernel.dispatch` | `game.advance_siege(selection)` | `siege`, `owner`, `dev`, `buildings` |
| `peace` | `_make_peace()` → `kernel.dispatch` | `game.make_peace(target_house)` | `truces`, `opinion`, ggf. `spouse` |
| `secret_discover` | `_discover_secret()` → `kernel.dispatch` | `game.discover_secret(target_house)` | `secrets` |
| `secret_expose` | `_expose_secret()` → `kernel.dispatch` | `game.expose_secret(target_house)` | `scandal`, `opinion`, `claims` |

`save` und `load` sind Randkommandos: Sie dürfen `Game.snapshot()` und `Game.restore()` benutzen, aber nie eigenes JSON schreiben. Das Schema bleibt in `SaveGame.gd`.

## Modalstapel

Der Kernel führt den Stapel als flüchtigen UI-Zustand. `set_base_modal()` setzt `start` oder `game`; `push_modal()` und `pop_modal(expected)` verwalten die darüberliegenden Ebenen. Ein doppeltes Öffnen desselben obersten Zustands wird ignoriert; ein `pop_modal()` mit falscher Erwartung lässt den Stapel unverändert.

| Zustand | Öffner | Schließer | Darf Spielzustand ändern |
|---|---|---|---|
| `start` | `_show_start()` | Spielstart | nein |
| `game` | `_start()` / `_create_begin()` / `_load()` | Spielende | nein |
| `new_game` | `_show_newgame()` | Zurück | nein |
| `create` | `_show_create()` | Zurück/Start | ja, nur beim Start |
| `customizer` | Porträt/Wappen | Abbrechen/Übernehmen | ja, nur nach Bestätigung |
| `picker` | Heiraten/Intrige | Ziel oder Zurück | nein |
| `event` | offenes Ereignis | Optionsknopf | ja, genau eine Option |
| `family_tree` | Stammbaum | Schließen | nein |
| `herrschaft` | Herrschaftsbutton | Schließen | ja, Rat, Gesetz und Bau über `Game`-Kommandos |

`game_over` ist ein eigenes Overlay (`over_layer`) und wird aus dem autoritativen `game.game_over` gerendert; es ist kein Eintrag im Stapel. „Neues Spiel“ ruft `_show_start()` auf und setzt den Stapel auf `start` zurück.

`Escape` schließt den obersten Eintrag für `herrschaft`, `customizer`, `create` und `new_game`. `picker`, `family_tree` und `event` haben sichtbare Schließen- beziehungsweise Wahlknöpfe; das Ereignis muss über eine Option aufgelöst werden. Nach `load` wird der Stapel auf `game` zurückgesetzt. Der Stapel wird **nicht** gespeichert.

## Umgesetzte Extraktion

| Schritt | Umsetzung | Verhaltensänderung | Gate |
|---|---|---|---|
| 1 | Kommando-IDs und `dispatch()` aus `Main.gd` herausgezogen; Buttons rufen nur noch `_dispatch()` | keine | `HousePlayTest`, `IntrigueTest`, `CustomizeTest` |
| 2 | Event- und Picker-Anzeige über `ViewModelBuilder` und Modalstapel gelöst | keine | dieselben Tests plus `SaveMigrationTest` |
| 3 | `refresh()` und `_refresh_rule()` beziehen Strings/Flags aus `ViewModelBuilder`; Rendering bleibt in `Main` | keine | `TouchTest`, `ShotTest` |
| 4 | `MapView`/`FamilyTree` behalten ihre bestehende `game`-Projektion; keine Änderung an der Karten- oder Baumdarstellung | keine | `MapTest`, `ShotTest` |
| 5 | `UiKernelTest` prüft Auswahl, Modalstapel, blockierte und gültige Kommandos, Save-Grenze und goldene View-Model-Strings | keine | `UiKernelTest` |

Die weitergehende Aufteilung der in `Main.gd` aufgebauten Panels in eigene Klassen ist eine mögliche Folgestufe, aber **kein Bestandteil und keine Voraussetzung** der abgeschlossenen UiKernel-Extraktion.

## Anti-Ziele

- Kein reaktives Framework und kein generischer State-Store. Godot-Signale und explizite Kommandos reichen.
- Keine UI-Logik in `Game.gd`, keine Regel-Logik in Panels.
- Kein Speichern von UI-Zustand (Auswahl, offene Modals, Button-Fokus) im Spielstand.
- Kein direktes `game.houses[...] = ...` aus einem Panel. Ausnahmen sind nur Leseoperationen.
- Keine vorzeitige Aufteilung von `Game.gd` in viele Manager, solange die Kanten nicht durch Tests belegt sind.

## Abnahme

Die UiKernel-Extraktion ist abgeschlossen. `Main.gd` bleibt Composition Root und Renderer; `UiKernel.gd` hält Auswahl und Modalstapel und routet alle Spielkommandos; `ViewModelBuilder.gd` liefert ausschließlich Anzeigezeichenketten und Flags. `Game.gd` bleibt autoritativ, `SaveGame.gd` bleibt für das Schema zuständig. Die Dateioperationen für Speichern und Laden bleiben in `Main.gd` und werden vom Kernel nur über Handler aufgerufen.

Regressionslauf vom 2026-11-06 (Godot 4.5.stable, Logs unter `build/verify/uikernel/`):

- Headless: `MapDataTest`, `MapTest`, `HouseTest`, `HousePlayTest`, `IntrigueTest`, `CustomizeTest`, `PortraitTest`, `SaveMigrationTest`, `SystemicDepthTest`, `FullDepthTest`, `StoryTest` — alle grün.
- Mit Fenster/Rendering: `TouchTest` (echter `InputEventScreenTouch`) und `ShotTest` (fünf Bilder, 1280×720) — beide grün.
- `UiKernelTest` — 35 Prüfungen, grün.

Die Testversion 1.3 ist aus dem aktuellen Stand gebaut (Artefakte unter `F:`, Hashes im README) und am 2026-11-08 im Windows-30-Minuten-Lauf bestanden (12/12 Aktionen, 3/3 Roundtrips, AI2+AI3; Beleg `build/verify/manual-build-d2cc-v2/`), aber noch nicht veröffentlicht; auf GitHub verteilt wird weiterhin 1.2: <https://github.com/chaotiKKK/kronen-und-kriege/releases/tag/v1.2>. `repo-compare/` blieb unverändert. Der Quellstand liegt auf `main`.
