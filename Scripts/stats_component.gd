class_name StatsComponent
extends Node
## Manages a collection of Stats for an entity.
##
## Attach this component to any character, enemy, or object that needs stats.
## This acts as a container and interface for multiple Stat resources.
##
## USAGE:
## 1. Add StatsComponent as a child node
## 2. Either set stat_definitions in the Inspector, OR
## 3. Create stats programmatically using stat_definitions array
##
## ARCHITECTURE:
## Player/Enemy
##   └── StatsComponent (this script)
##         └── Contains: health, stamina, strength, etc.
##
## Stat definitions are duplicated at runtime, so every instance has its own
## values even when several enemies share the same .tres files.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when any stat's current value changes
signal stat_changed(stat_name: StringName, old_value: float, new_value: float)

## Emitted when any stat reaches its minimum value (e.g., health = 0)
signal stat_depleted(stat_name: StringName)

## Generic signal for UI updates - emitted when base values or modifiers change
signal any_stat_modified()

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

## Array of Stat resources that define this entity's stats.
## You can either:
## - Create .tres files for each stat and assign them here
## - Create stats programmatically in code using Stat.new()
@export var stat_definitions: Array[Stat] = []

## Stats that are POOLS: spent and refilled at runtime (health, stamina, mana).
## get_value() returns a pool's live current_value. Every other stat is an
## ATTRIBUTE (strength, defense, ...) and get_value() returns its fully modified
## value, so equipment, buffs and spent stat points actually take effect.
@export var pool_stats: Array[StringName] = [&"health", &"stamina", &"mana"]

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Runtime dictionary for fast lookup: StringName -> Stat
## This is populated from stat_definitions during _ready()
var _stats: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_initialize_stats()


## Initialize all stats from the stat_definitions array.
## Called automatically in _ready(), but can be called manually if you
## set up stats programmatically after the node is ready.
func _initialize_stats() -> void:
	for stat_def in stat_definitions:
		# IMPORTANT: Duplicate so each instance has its own stat data
		# Without this, all instances would share the same stat values!
		var stat: Stat = stat_def.duplicate()
		stat.initialize()
		_stats[stat.stat_name] = stat

		# Connect to individual stat signals
		stat.value_changed.connect(_on_stat_value_changed)
		stat.depleted.connect(_on_stat_depleted)

# =============================================================================
# STAT ACCESS METHODS
# =============================================================================

## Get a Stat by name. Returns null if not found.
## Example: var health = stats.get_stat(&"health")
func get_stat(stat_name: StringName) -> Stat:
	return _stats.get(stat_name)


## Check if this component has a specific stat
func has_stat(stat_name: StringName) -> bool:
	return stat_name in _stats


## Get the value of a stat. Pools (see pool_stats) return their live
## current_value; attributes return their modified value (base + modifiers).
## Returns 0.0 if the stat doesn't exist.
func get_value(stat_name: StringName) -> float:
	var stat := get_stat(stat_name)
	if not stat:
		return 0.0
	if stat_name in pool_stats:
		return stat.current_value
	return stat.max_computed


## Add a stat at runtime if it doesn't exist yet. Safe to call more than once.
func ensure_stat(stat_name: StringName, base: float, min_v: float = 0.0, max_v: float = 999.0) -> void:
	if _stats.has(stat_name):
		return
	var stat := Stat.new(stat_name, base, min_v, max_v)
	stat.initialize()
	_stats[stat_name] = stat
	stat.value_changed.connect(_on_stat_value_changed)
	stat.depleted.connect(_on_stat_depleted)


## Get max computed value of a stat
func get_max_value(stat_name: StringName) -> float:
	var stat := get_stat(stat_name)
	return stat.max_computed if stat else 0.0

# =============================================================================
# STAT MODIFICATION METHODS
# =============================================================================

## Set current value of a stat directly
func set_value(stat_name: StringName, value: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.current_value = value


## Modify current value by an amount (positive or negative)
## Example: stats.modify_value(&"health", -20)  # Take 20 damage
## Example: stats.modify_value(&"health", 30)   # Heal 30 HP
func modify_value(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.current_value += amount


## Increase base value permanently (used by leveling system)
## This increases the stat's maximum, not just current value
func increase_base(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.base_value += amount
		any_stat_modified.emit()

# =============================================================================
# MODIFIER METHODS (for equipment, buffs, etc.)
# =============================================================================

## Add a flat modifier to a stat (e.g., +10 strength from a sword)
func add_flat_modifier(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.add_flat_modifier(amount)
		any_stat_modified.emit()


## Remove a flat modifier from a stat
func remove_flat_modifier(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.remove_flat_modifier(amount)
		any_stat_modified.emit()


## Add a percent modifier to a stat (0.25 = +25% bonus)
func add_percent_modifier(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.add_percent_modifier(amount)
		any_stat_modified.emit()


## Remove a percent modifier from a stat
func remove_percent_modifier(stat_name: StringName, amount: float) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.remove_percent_modifier(amount)
		any_stat_modified.emit()

# =============================================================================
# SOURCE-TAGGED MODIFIERS (equipment, upgrades, statuses)
# =============================================================================

## Set or replace one source's modifier on one stat.
## Example: set_modifier(&"strength", &"equipment/iron_sword", 20.0)
func set_modifier(stat_name: StringName, source_id: StringName, flat: float, percent: float = 0.0) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.set_modifier(source_id, flat, percent)
		any_stat_modified.emit()


## Remove one source's modifier from one stat.
func clear_modifier(stat_name: StringName, source_id: StringName) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.clear_modifier(source_id)
		any_stat_modified.emit()


## Remove a source's modifier from EVERY stat. One item can grant +strength and
## +defense under the same "equipment/<id>" source; this takes both off.
func clear_source(source_id: StringName) -> void:
	for stat: Stat in _stats.values():
		stat.clear_modifier(source_id)
	any_stat_modified.emit()


## Remove every modifier whose source starts with `prefix`, across all stats.
## Example: clear_modifiers_from_prefix("upgrade/") at the end of a run.
func clear_modifiers_from_prefix(prefix: String) -> void:
	for stat: Stat in _stats.values():
		stat.clear_modifiers_from_prefix(prefix)
	any_stat_modified.emit()

# =============================================================================
# UTILITY METHODS
# =============================================================================

## Restore a specific stat to full
func restore_stat(stat_name: StringName) -> void:
	var stat := get_stat(stat_name)
	if stat:
		stat.restore_full()


## Restore all stats to full (like resting at a bonfire)
func restore_all_stats() -> void:
	for stat: Stat in _stats.values():
		stat.restore_full()


## Get all stat names in this component
func get_all_stat_names() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(_stats.keys())
	return names


## Get dictionary snapshot of all stats (useful for saving/debugging)
func get_stats_snapshot() -> Dictionary:
	var snapshot := {}
	for stat_name: StringName in _stats:
		var stat: Stat = _stats[stat_name]
		snapshot[stat_name] = {
			"base": stat.base_value,
			"current": stat.current_value,
			"max": stat.max_computed
		}
	return snapshot


## Load stats from a snapshot (for loading saved games)
func load_stats_snapshot(snapshot: Dictionary) -> void:
	for stat_name: StringName in snapshot:
		var stat := get_stat(stat_name)
		if stat:
			var data: Dictionary = snapshot[stat_name]
			stat.base_value = data.get("base", stat.base_value)
			stat.current_value = data.get("current", stat.max_computed)

# =============================================================================
# SIGNAL HANDLERS (internal)
# =============================================================================

func _on_stat_value_changed(stat: Stat, old_value: float, new_value: float) -> void:
	stat_changed.emit(stat.stat_name, old_value, new_value)


func _on_stat_depleted(stat: Stat) -> void:
	stat_depleted.emit(stat.stat_name)
