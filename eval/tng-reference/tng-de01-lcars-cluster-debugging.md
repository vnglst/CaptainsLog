# TNG-DE01: Fehlersuche im LCARS-Cluster

**Language:** German
**Recording target:** ~1 minute (comfortable speaking pace)
**Categories:** work, technical
**Audio filename:** `tng-de01-lcars-cluster-debugging.m4a`
**Recording status:** To be recorded by the owner.

## Raw Script

So, der LCARS-Cluster läuft wieder. Geordi La Forge und ich haben heute eine halbe Stunde nach dem Fehler gesucht. Die neuen Container blieben einfach hängen. Erst dachten wir, es fehlt Speicher, aber daran lag es nicht.

Data Chen hat dann die Konfiguration mit uns durchgesehen. In einem Label fehlte ein Bindestrich. Deshalb passte es nicht zum Selektor, und die Container konnten keinem Knoten zugeordnet werden. Im alten Pool war derselbe Tippfehler hinterlegt. Dort hatte es also nur zufällig funktioniert.

Wir haben beide Stellen korrigiert. Morgen ergänze ich eine automatische Prüfung, damit uns das bei der Warp Drive Migration nicht noch mal passiert.

Worf möchte außerdem einen kurzen Bericht. Den schreibe ich morgen. Beim nächsten Mal halte ich gleich fest, was wir schon geprüft haben. Heute haben Geordi und ich einiges doppelt gemacht.

## Polished Version

Der LCARS-Cluster läuft wieder. Geordi La Forge und ich haben eine halbe Stunde nach dem Fehler gesucht, weil die neuen Container hängen blieben. Speicher war ausreichend vorhanden.

Data Chen hat mit uns die Konfiguration geprüft. In einem Label fehlte ein Bindestrich. Es passte deshalb nicht zum Selektor, sodass die Container keinem Knoten zugeordnet werden konnten. Im alten Pool war derselbe Tippfehler hinterlegt; dort hatte es zufällig funktioniert.

Wir haben beide Stellen korrigiert. Morgen ergänze ich eine automatische Prüfung für die Warp Drive Migration und schreibe den kurzen Bericht, den Worf angefordert hat.

Bei der nächsten Fehlersuche möchte ich die geprüften Schritte direkt notieren. Geordi und ich haben heute einiges doppelt gemacht.

## Expected YAML Frontmatter

```yaml
---
date: "2025-04-16"
recording_time: "12:00"
language: "German"
categories:
  - "work"
  - "technical"
tags:
  - "debugging"
  - "configuration"
  - "infrastructure"
persons:
  - "Geordi La Forge"
  - "Data Chen"
  - "Worf"
projects:
  - "Warp Drive Migration"
companies: []
entities:
  - "LCARS-Cluster"
summary: "Data fand bei der gemeinsamen Fehlersuche einen fehlenden Bindestrich in einem Label. Derselbe Tippfehler im alten Pool hatte das Problem verdeckt. Beide Stellen sind korrigiert; eine automatische Prüfung und Worfs Bericht sind für morgen geplant. Künftig sollen geprüfte Schritte gleich notiert werden."
---
```

## Expected Filename

```
2025-04-16-lcars-cluster-label-tippfehler.md
```
