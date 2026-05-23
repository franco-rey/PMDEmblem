class_name DamageResult
extends RefCounted
## Immutable-ish result object returned by DamageResolver.

var hit: bool = false
var damage: int = 0
var effectiveness: float = 1.0
var stab: bool = false
var is_critical: bool = false
var pp_used: int = 0
var effect_tags: Array[String] = []
