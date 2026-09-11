class_name BlockCatalog
extends Resource
## Explicit manifest of production/development block definitions shipped with the game.
## Runtime loading is manifest-driven rather than filesystem-scanned for deterministic PCK behavior.

@export var blocks: Array[Resource] = []
