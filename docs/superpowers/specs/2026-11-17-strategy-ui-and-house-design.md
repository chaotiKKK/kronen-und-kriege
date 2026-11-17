# Strategieansichten und eigener Multiplayer-Hausstart

## Autorisierung und Umfang

Der Nutzer verlangt deutlich unterschiedliche Kartenmodi, Provinzdetails direkt unter dem Hauskopf, sachlich geordnete Navigation, tiefere Forschung, abwechslungsreiche Ereignisse und funktionierende Hofverwaltung. Zusätzlich soll jeder Spieler vor einer WLAN-Partie ein eigenes Haus samt begrenzter Armeedoktrin gestalten können. Die frühere ausdrückliche Freigabe zum selbstständigen Entscheiden gilt weiter. Der Hofbefund wurde konkretisiert: Verwaltung und Aktionen, nicht Hofraum oder Einklappen der Leiste.

## Karten und Provinzen

Fünf Ansichten: Politik zeigt tatsächliche Besitzer; Gelände zeigt Topografie mit festen angestammten Königreichs-/Reichsgrenzen; Rechtstitel vereinigt die bisherigen Titel/Reiche mit umschaltbarer Herzogtums-, Königreichs- und Reichsebene; Wirtschaft zeigt Ertrag/Entwicklung und Infrastruktur; Krieg zeigt Angriffsreichweite, Truppen und Belagerungen. Alte interne Moduskennungen werden als Aliase angenommen. Die Ansichten unterscheiden sich durch Flächen, Grenzprioritäten, Beschriftungen und Legenden. Der Atlas und die 108 Gebiete bleiben geometrisch unverändert.

Ein einfacher Provinzklick öffnet den rechten Hof, aktiviert die Provinzansicht und zeigt unter dem unveränderten Hauskopf unmittelbar Gelände, Eigentümer, Einkommen, Entwicklung, Gebäude mit Kosten/Wirkung, Heer/Flotte sowie Wissen und anwendbare Errungenschaften. Die hausweite Forschung wird ausdrücklich als solche bezeichnet. Gegnerisches Eigentum darf betrachtet, aber nicht ausgebaut werden. Aktionen laufen ausschließlich über Main._dispatch/UiKernel/Game.

Speichern/Laden/Verlassen bleiben in der Spielverwaltung. Die WLAN-Lobby ist im Titelmenü und bei aktiver Netzpartie über die Netzverwaltung erreichbar. Der Weltbereich enthält spielweltbezogene Information und Forschung, keine Dateiverwaltung.

## Forschung und Ereignisse

Die vorhandenen Innovations-IDs und ihre bisherigen Anfangskosten/-dauern bleiben bestehen. Etwa 14–18 Innovationen erhalten Zweig, Beschreibung, Voraussetzungen, Dauer, Preis und tatsächlich angewendete Wirkungen. Die neue Regionsgewichtung wird nicht durch flache Erträge pro Region ausgehebelt. Der Anfangszustand ohne neue Forschung behält seine Balance.

Mindestens 32 statische Ereignisdefinitionen mit Bedingungen und angemessenen Kategorien. Die letzten sechs Ereignisse pro Haus werden berücksichtigt; unmittelbare Wiederholung ist bei mehreren möglichen Fällen ausgeschlossen. Der Host ist die einzige Zufallsinstanz im WLAN. Alte ausstehende Ereignis-IDs bleiben ladbar, neue Historie und Forschung überstehen Speichern/Laden.

## Hof

Aktions-Nodes bleiben bei Monatswechsel, Refresh und Netzwerkbestätigung bestehen. Kosten, Wirkung, Unterhalt, Sperrgründe und Ergebnis stehen im geöffneten Hof. Gäste sehen ausstehende Bestätigung und können dieselbe Aktion nicht mehrfach absenden. Hoftag veranstalten verwendet die vorhandene Regel 40 Gold gegen 12 Prestige. Es gibt einen übersichtlichen vertikalen Verwaltungsfluss mit erreichbarem Schließen bei 200-Prozent-Text.

## Gemeinsamer Hausdesigner

HouseDesign ist ein reines, gemeinsam verwendetes Modell. Einzelspieler und Lobby bearbeiten zunächst einen Entwurf. Namen, Geschlecht, Alter, eingebettetes Porträt/Wappen, Palette, Heimat, vier Charakterwerte und Doktrin sind begrenzt. Die Werte liegen jeweils zwischen 3 und 20 und zusammen bei höchstens 44. Erlaubte Doktrinen: balanced, infantry, cavalry, siege. Sie erhalten dieselbe Anfangsstärke mit erklärten Vor-/Nachteilen; ihre Wirkungen werden in tatsächlichen Spielregeln geprüft.

Clients können keine Ressourcen, Dateiwege, Hausindizes oder Armeeobjekte einschleusen. Der Host validiert den höchstens 2-KiB-Entwurf, reserviert eine eindeutige Heimat und nimmt bei Änderungen die Bereitschaft zurück. Startgebiete bereits von Menschen gewählter vorhandener Häuser sind geschützt. Eigene Häuser werden erst beim Start in stabiler Peer-Reihenfolge zusätzlich zu den neun NPC-Häusern angelegt. Wiederaufnahmelobbys verwenden einen validierten dynamischen Hauskatalog; der Designer bleibt dort gesperrt. Gültige lokale 1.8-Spielstände werden getrennt von der Netzwerkversionsprüfung übernommen und gesichert.

## Abnahme

Testgetriebene Regeln und Integrationen, echte unterschiedliche Renderaufnahmen der fünf Modi, Provinzklick ohne zusätzliches Öffnen, direkte lokale Bauaktion, gültige und verweigerte Forschung, abwechslungsreiche bedingte Ereignisse, stabile Hofaktion samt sichtbarer Bestätigung, zwei bis vier eigene Netzwerkhäuser mit identischen Welthashes, Save/Load und Wiederaufnahme. Desktop normal/200 Prozent und Android-Touch werden getrennt geprüft. Sichtbare Windows-Fenster liegen ausschließlich auf dem rechten physischen Monitor. Kein Smartphonezugriff ohne neuen exklusiven Geräteslot; jeder Emulator erhält eigene Identität/Ports. Vorhandene Signatur-/Hardware-/Quellencachegrenzen werden nicht als behoben ausgegeben.
