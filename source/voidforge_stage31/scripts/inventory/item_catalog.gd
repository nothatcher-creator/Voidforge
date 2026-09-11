class_name ItemCatalog
extends Resource
## Explicit production-item manifest.
##
## Runtime code loads this resource instead of enumerating directories. Keeping content
## discovery explicit makes Android/PCK behavior deterministic and makes missing catalog
## entries detectable by development tooling.

@export var items: Array[Resource] = []
