class_name StatPresets
extends RefCounted
## Factory class for creating common stat configurations.
##
## Use these static methods to quickly set up stats without manually
## creating each Stat resource. Great for prototyping and consistency.
##
## USAGE:
##   # Single stat
##   var health = StatPresets.create_health(100.0)
##
##   # Full preset
##   stats.stat_definitions = StatPresets.get_soulslike_stats()

# =============================================================================
# INDIVIDUAL STAT CREATORS
# =============================================================================

## Create a basic health stat (resource that can be depleted)
## - min: 0 (can die)
## - max: high cap for scaling
static func create_health(base: float = 100.0, max_cap: float = 9999.0) -> Stat:
	return Stat.new(&"health", base, 0.0, max_cap)


## Create a stamina stat (for actions like dodging, sprinting)
static func create_stamina(base: float = 100.0, max_cap: float = 999.0) -> Stat:
	return Stat.new(&"stamina", base, 0.0, max_cap)


## Create a mana/MP/FP stat (for magic abilities)
static func create_mana(base: float = 50.0, max_cap: float = 999.0) -> Stat:
	return Stat.new(&"mana", base, 0.0, max_cap)


## Create a strength stat (affects physical damage)
## - min: 1 (always has some strength)
## - max: 99 (soft cap for balance)
static func create_strength(base: float = 10.0) -> Stat:
	return Stat.new(&"strength", base, 1.0, 99.0)


## Create a dexterity stat (affects speed, skill damage, critical hits)
static func create_dexterity(base: float = 10.0) -> Stat:
	return Stat.new(&"dexterity", base, 1.0, 99.0)


## Create an intelligence stat (affects magic damage, mana pool)
static func create_intelligence(base: float = 10.0) -> Stat:
	return Stat.new(&"intelligence", base, 1.0, 99.0)


## Create a vitality stat (increases max health when leveled)
static func create_vitality(base: float = 10.0) -> Stat:
	return Stat.new(&"vitality", base, 1.0, 99.0)


## Create an endurance stat (increases max stamina when leveled)
static func create_endurance(base: float = 10.0) -> Stat:
	return Stat.new(&"endurance", base, 1.0, 99.0)


## Create a luck stat (affects drop rates, critical chance)
static func create_luck(base: float = 10.0) -> Stat:
	return Stat.new(&"luck", base, 1.0, 99.0)


## Create a defense/armor stat (reduces incoming damage)
static func create_defense(base: float = 10.0) -> Stat:
	return Stat.new(&"defense", base, 0.0, 999.0)


## Create an agility stat (affects dodge chance, movement speed)
static func create_agility(base: float = 10.0) -> Stat:
	return Stat.new(&"agility", base, 1.0, 99.0)

# =============================================================================
# PRESET COLLECTIONS
# =============================================================================

## Get a full souls-like stat array (Dark Souls / Elden Ring style)
## Includes: health, stamina, mana, vitality, endurance, strength, dexterity,
##           intelligence, luck
static func get_soulslike_stats() -> Array[Stat]:
	return [
		create_health(100.0),
		create_stamina(80.0),
		create_mana(50.0),
		create_vitality(10.0),
		create_endurance(10.0),
		create_strength(10.0),
		create_dexterity(10.0),
		create_intelligence(10.0),
		create_luck(7.0),
	]


## Get a simple RPG stat array (classic JRPG style)
## Includes: health, mana, strength, dexterity, intelligence
static func get_simple_rpg_stats() -> Array[Stat]:
	return [
		create_health(100.0),
		create_mana(50.0),
		create_strength(10.0),
		create_dexterity(10.0),
		create_intelligence(10.0),
	]


## Get action game stats (no magic system)
## Includes: health, stamina, strength, dexterity
static func get_action_stats() -> Array[Stat]:
	return [
		create_health(100.0),
		create_stamina(100.0),
		create_strength(10.0),
		create_dexterity(10.0),
	]


## Get survival game stats
## Includes: health, stamina, hunger, thirst
static func get_survival_stats() -> Array[Stat]:
	return [
		create_health(100.0),
		create_stamina(100.0),
		Stat.new(&"hunger", 100.0, 0.0, 100.0),
		Stat.new(&"thirst", 100.0, 0.0, 100.0),
	]


## Get minimal stats (just health)
## Good for simple enemies or objects
static func get_minimal_stats() -> Array[Stat]:
	return [
		create_health(100.0),
	]
