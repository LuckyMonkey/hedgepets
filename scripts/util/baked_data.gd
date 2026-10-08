class_name BakedData
extends Resource

## Pre-built meshes (see bake_cache.gd): key -> Mesh / MultiMesh / Array of them, and the fingerprint of the generator
## code they were made with.
@export var items := {}
@export var salt := ""
