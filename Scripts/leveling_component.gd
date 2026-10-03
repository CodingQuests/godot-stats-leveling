class_name LevelingComponent
extends Node
## Handles experience points, leveling, and stat point allocation.
##
## This component works alongside StatsComponent to provide a complete
## RPG-style progression system. Players gain XP, level up, and spend
## stat points to permanently increase their stats.
##
## The XP curve is exponential: base_xp * scaling^(level - 2). One add_xp() call
## can level up several times. Stat points raise a stat's base value for good.
##
## USAGE:
## 1. Add LevelingComponent as a sibling to StatsComponent
## 2. Set the stats_component_path to point to the StatsComponent
## 3. Call add_xp() when the player defeats enemies, completes quests, etc.
## 4. Call spend_stat_point() when the player allocates stat points
##
## ARCHITECTURE:
## Player
##   ├── StatsComponent  <── stats_component_path points here
##   └── LevelingComponent (this script)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when XP is gained
signal xp_gained(amount: int, total: int)

## Emitted when the player levels up
signal level_up(new_level: int, stat_points_awarded: int)

## Emitted when a stat point is spent
signal stat_point_spent(stat_name: StringName, points_remaining: int)

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

## Path to the StatsComponent this leveling system controls.
## Set this in the Inspector to point to the sibling StatsComponent.
@export_node_path("StatsComponent") var stats_component_path: NodePath

## The resolved StatsComponent reference (set in _ready)
var stats_component: StatsComponent

@export_group("Leveling Config")

## Maximum level the player can reach
@export var max_level: int = 100

## XP needed to reach level 2 (the base for the scaling formula)
@export var base_xp_requirement: int = 100

## How much XP requirement grows per level (1.5 = 50% more each level)
@export var xp_scaling_factor: float = 1.5

## How many stat points are awarded per level up
@export var stat_points_per_level: int = 3

# =============================================================================
# CURRENT STATE
# =============================================================================

## The player's current level (starts at 1)
var current_level: int = 1

## XP accumulated toward the next level (resets after leveling)
var current_xp: int = 0

## Stat points available to spend
var available_stat_points: int = 0

## Cost to increase each stat (StringName -> int). Default is 1 for all stats.
## You can customize this to make some stats cost more points.
var stat_costs: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Resolve the StatsComponent from the NodePath
	if stats_component_path:
		stats_component = get_node(stats_component_path) as StatsComponent

	# Set default costs for all stats (1 point each)
	if stats_component:
		for stat_name in stats_component.get_all_stat_names():
			if stat_name not in stat_costs:
				stat_costs[stat_name] = 1
	else:
		push_warning("LevelingComponent: No StatsComponent found at path: %s" % stats_component_path)

# =============================================================================
# XP CALCULATION METHODS
# =============================================================================

## Calculate XP required to reach a specific level.
## Uses an exponential formula: base * scaling^(level-2)
## Level 2 needs base_xp, Level 3 needs base_xp * scaling, etc.
func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(base_xp_requirement * pow(xp_scaling_factor, level - 2))


## Get total XP required from level 1 to reach target level
func get_total_xp_for_level(level: int) -> int:
	var total := 0
	for lvl in range(2, level + 1):
		total += get_xp_for_level(lvl)
	return total


## Get XP needed to reach the next level from current level
func get_xp_to_next_level() -> int:
	if current_level >= max_level:
		return 0
	return get_xp_for_level(current_level + 1)


## Get progress ratio toward next level (0.0 to 1.0)
## Useful for XP progress bars
func get_level_progress() -> float:
	var xp_needed := get_xp_to_next_level()
	if xp_needed == 0:
		return 1.0
	return float(current_xp) / float(xp_needed)

# =============================================================================
# XP AND LEVELING METHODS
# =============================================================================

## Add XP and handle automatic level ups.
## Call this when the player defeats enemies, completes quests, etc.
func add_xp(amount: int) -> void:
	if current_level >= max_level:
		return

	current_xp += amount
	xp_gained.emit(amount, current_xp)

	# Check for level ups (can level up multiple times at once)
	while current_xp >= get_xp_to_next_level() and current_level < max_level:
		var xp_needed := get_xp_to_next_level()
		current_xp -= xp_needed
		current_level += 1
		available_stat_points += stat_points_per_level
		level_up.emit(current_level, stat_points_per_level)

	# Cap XP at max level
	if current_level >= max_level:
		current_xp = 0

# =============================================================================
# STAT POINT METHODS
# =============================================================================

## Spend stat points to permanently increase a stat's base value.
## Returns true if successful, false if not enough points or stat not found.
func spend_stat_point(stat_name: StringName, amount: int = 1) -> bool:
	if not stats_component:
		push_error("LevelingComponent: No StatsComponent assigned!")
		return false

	if not stats_component.has_stat(stat_name):
		push_warning("LevelingComponent: Stat '%s' not found!" % stat_name)
		return false

	var cost: int = stat_costs.get(stat_name, 1) * amount

	if available_stat_points < cost:
		return false

	available_stat_points -= cost
	stats_component.increase_base(stat_name, float(amount))
	stat_point_spent.emit(stat_name, available_stat_points)
	return true


## Check if player can afford to increase a stat
func can_spend_on_stat(stat_name: StringName, amount: int = 1) -> bool:
	var cost: int = stat_costs.get(stat_name, 1) * amount
	return available_stat_points >= cost


## Get the cost to increase a specific stat by 1 point
func get_stat_cost(stat_name: StringName) -> int:
	return stat_costs.get(stat_name, 1)


## Set a custom cost for a stat (e.g., make "luck" cost 2 points)
func set_stat_cost(stat_name: StringName, cost: int) -> void:
	stat_costs[stat_name] = cost

# =============================================================================
# SAVE/LOAD METHODS
# =============================================================================

## Get save data for persistence
func get_save_data() -> Dictionary:
	return {
		"level": current_level,
		"xp": current_xp,
		"stat_points": available_stat_points
	}


## Load from save data
func load_save_data(data: Dictionary) -> void:
	current_level = data.get("level", 1)
	current_xp = data.get("xp", 0)
	available_stat_points = data.get("stat_points", 0)

# =============================================================================
# DEBUG METHODS
# =============================================================================

## Print current leveling status to console
func debug_print() -> void:
	print("=== Leveling Status ===")
	print("Level: %d / %d" % [current_level, max_level])
	print("XP: %d / %d (%.1f%%)" % [current_xp, get_xp_to_next_level(), get_level_progress() * 100])
	print("Available Stat Points: %d" % available_stat_points)
