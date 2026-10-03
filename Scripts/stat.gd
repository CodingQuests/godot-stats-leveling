class_name Stat
extends Resource
## A single stat with base value, modifiers, and optional min/max bounds.
##
## This is the core building block of the stats system. Each Stat represents
## one attribute like "health", "strength", or "mana".
##
## KEY CONCEPTS:
## - base_value: The permanent value (increases when leveling up)
## - current_value: The dynamic value (decreases when taking damage, etc.)
## - max_computed: Calculated from base_value + modifiers
## - Modifiers: Temporary bonuses (equipment, buffs, etc.)
##
## Final value formula: (base_value + flat) * (1 + percent), clamped to
## [min_value, max_value]. Equipment and buffs add modifiers; leveling raises
## base_value permanently.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted whenever current_value changes
signal value_changed(stat: Stat, old_value: float, new_value: float)

## Emitted when current_value reaches min_value (e.g., health hits 0)
signal depleted(stat: Stat)

# =============================================================================
# EXPORTED PROPERTIES (visible in the Inspector)
# =============================================================================

## Unique identifier for this stat (e.g., &"health", &"strength")
@export var stat_name: StringName = &"unnamed"

## The base value before any modifiers are applied
@export var base_value: float = 10.0

## The minimum possible value (usually 0 for resources, 1 for attributes)
@export var min_value: float = 0.0

## The maximum possible value (set to INF for no cap)
@export var max_value: float = 999.0

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Summed modifiers with no source (add_flat_modifier / add_percent_modifier).
## Fine for a quick buff. For anything you need to remove later, prefer the
## source-tagged API below.
var _flat_modifiers: float = 0.0
var _percent_modifiers: float = 0.0

## Source-tagged modifiers: source_id (StringName) -> {"flat": float, "percent": float}.
## This is what makes stackable, individually removable bonuses possible.
## Example sources: &"equipment/iron_sword", &"upgrade/swift_strikes",
## &"status/weakness".
var _mods: Dictionary = {}

## The actual current value (private, use current_value property)
var _current_value: float = 0.0

## Tracks if initialize() has been called
var _initialized: bool = false

# =============================================================================
# COMPUTED PROPERTIES
# =============================================================================

## The maximum possible value after all modifiers (summed and source-tagged).
## Formula: (base_value + all flat) * (1 + all percent)
## Example: base=100, flat=+20, percent=+0.25 -> (100+20) * 1.25 = 150
var max_computed: float:
	get:
		var flat := _flat_modifiers
		var percent := _percent_modifiers
		for mod: Dictionary in _mods.values():
			flat += mod.get("flat", 0.0)
			percent += mod.get("percent", 0.0)
		return clampf((base_value + flat) * (1.0 + percent), min_value, max_value)


## Current value property with automatic clamping and signal emission.
## Setting this will clamp between min_value and max_computed.
var current_value: float:
	get: return _current_value
	set(value):
		var old := _current_value
		_current_value = clampf(value, min_value, max_computed)
		if not is_equal_approx(old, _current_value):
			value_changed.emit(self, old, _current_value)
			if is_equal_approx(_current_value, min_value):
				depleted.emit(self)

# =============================================================================
# CONSTRUCTOR
# =============================================================================

## Create a new Stat with the given parameters.
## Usage: Stat.new(&"health", 100.0, 0.0, 9999.0)
func _init(p_name: StringName = &"", p_base: float = 10.0, p_min: float = 0.0, p_max: float = 999.0) -> void:
	stat_name = p_name
	base_value = p_base
	min_value = p_min
	max_value = p_max

# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Initialize the stat by setting current_value to max_computed.
## Call this after setting base values, typically done by StatsComponent.
func initialize() -> void:
	if _initialized:
		return
	_current_value = max_computed
	_initialized = true


## Add a flat modifier (e.g., +10 strength from equipment)
func add_flat_modifier(amount: float) -> void:
	_flat_modifiers += amount
	# Re-clamp current value in case max decreased
	current_value = _current_value


## Remove a flat modifier
func remove_flat_modifier(amount: float) -> void:
	_flat_modifiers -= amount
	current_value = _current_value


## Add a percent modifier (0.1 = +10% bonus)
func add_percent_modifier(amount: float) -> void:
	_percent_modifiers += amount
	current_value = _current_value


## Remove a percent modifier
func remove_percent_modifier(amount: float) -> void:
	_percent_modifiers -= amount
	current_value = _current_value


# =============================================================================
# SOURCE-TAGGED MODIFIERS (equipment, upgrades, statuses)
# =============================================================================

## Set (add or replace) the modifier from one source. Setting the same source
## again overwrites it, so re-applying an upgrade never double-counts.
## flat is added; percent 0.25 means +25%.
func set_modifier(source_id: StringName, flat: float, percent: float = 0.0) -> void:
	_mods[source_id] = {"flat": flat, "percent": percent}
	current_value = _current_value  # re-clamp against the new max


## Remove one source's modifier. Every other source stays.
func clear_modifier(source_id: StringName) -> void:
	if _mods.erase(source_id):
		current_value = _current_value


## Remove every modifier whose source id starts with `prefix`.
## Example: clear_modifiers_from_prefix("upgrade/") wipes all run upgrades.
func clear_modifiers_from_prefix(prefix: String) -> void:
	var changed := false
	for key: StringName in _mods.keys():
		if String(key).begins_with(prefix):
			_mods.erase(key)
			changed = true
	if changed:
		current_value = _current_value


## True if this source currently has a modifier on the stat.
func has_modifier(source_id: StringName) -> bool:
	return _mods.has(source_id)


## Every source currently modifying this stat, with its values.
## Returns source_id -> {"flat": float, "percent": float}.
func get_modifiers() -> Dictionary:
	return _mods.duplicate(true)

# =============================================================================
# UTILITY
# =============================================================================

## Restore current_value to max_computed (full heal/restore)
func restore_full() -> void:
	current_value = max_computed


## Check if stat is at minimum (e.g., health == 0)
func is_depleted() -> bool:
	return is_equal_approx(_current_value, min_value)


## Check if stat is at maximum (fully restored)
func is_full() -> bool:
	return is_equal_approx(_current_value, max_computed)


## Get ratio of current to max (useful for UI progress bars)
## Returns 0.0 to 1.0
func get_ratio() -> float:
	if is_zero_approx(max_computed):
		return 0.0
	return _current_value / max_computed
