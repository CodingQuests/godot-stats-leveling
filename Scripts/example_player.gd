extends Node
## Demo driver for the stats and leveling system. Wires the buttons and hotkeys
## to StatsComponent and LevelingComponent, and redraws the character sheet.
##
## This script is demo scaffolding. The system itself is Stat, StatsComponent,
## LevelingComponent and StatPresets.

## Modifier sources. Any StringName works; a "category/name" pattern lets
## clear_modifiers_from_prefix("equipment/") strip a whole category at once.
const IRON_SWORD := &"equipment/iron_sword"
const BLESSING := &"buff/blessing"

const LOG_LINES := 4

@onready var stats: StatsComponent = $StatsComponent
@onready var leveling: LevelingComponent = $LevelingComponent
@onready var sheet: RichTextLabel = %StatsLabel

## Create the stats in code (no .tres files needed). Turn this off to use the
## stat_definitions set on the StatsComponent in the Inspector instead.
@export var use_programmatic_stats := true

var _log: Array[String] = []
var _saved: Dictionary = {}


func _ready() -> void:
	if use_programmatic_stats and stats.stat_definitions.is_empty():
		stats.stat_definitions = [
			Stat.new(&"health", 100.0, 0.0, 9999.0),
			Stat.new(&"stamina", 80.0, 0.0, 999.0),
			Stat.new(&"mana", 50.0, 0.0, 999.0),
			Stat.new(&"strength", 10.0, 1.0, 99.0),
			Stat.new(&"dexterity", 10.0, 1.0, 99.0),
			Stat.new(&"vitality", 10.0, 1.0, 99.0),
		]
		stats._initialize_stats()

	stats.stat_depleted.connect(_on_stat_depleted)
	leveling.xp_gained.connect(_on_xp_gained)
	leveling.level_up.connect(_on_level_up)
	leveling.stat_point_spent.connect(_on_stat_point_spent)
	_connect_buttons()
	_log_event("Ready. Use the buttons or the hotkeys.")
	_update_ui()


func _connect_buttons() -> void:
	%DamageButton.pressed.connect(_damage)
	%HealButton.pressed.connect(_heal)
	%StaminaButton.pressed.connect(_use_stamina)
	%ManaButton.pressed.connect(_use_mana)
	%XP50Button.pressed.connect(_gain_xp.bind(50))
	%XP200Button.pressed.connect(_gain_xp.bind(200))
	%StrButton.pressed.connect(_spend.bind(&"strength"))
	%DexButton.pressed.connect(_spend.bind(&"dexterity"))
	%VitButton.pressed.connect(_spend.bind(&"vitality"))
	%SwordButton.toggled.connect(_set_sword)
	%BlessingButton.toggled.connect(_set_blessing)
	%RestButton.pressed.connect(_rest)
	%SaveButton.pressed.connect(_save)
	%LoadButton.pressed.connect(_load)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_H: _damage()
		KEY_J: _heal()
		KEY_K: _use_stamina()
		KEY_L: _use_mana()
		KEY_X: _gain_xp(50)
		KEY_Z: _gain_xp(200)
		KEY_1: _spend(&"strength")
		KEY_2: _spend(&"dexterity")
		KEY_3: _spend(&"vitality")
		KEY_M: %SwordButton.button_pressed = not %SwordButton.button_pressed
		KEY_N: %BlessingButton.button_pressed = not %BlessingButton.button_pressed
		KEY_R: _rest()


# --- Actions -------------------------------------------------------------

func _damage() -> void:
	stats.modify_value(&"health", -20.0)
	_log_event("Took 20 damage.")
	_update_ui()


func _heal() -> void:
	stats.modify_value(&"health", 30.0)
	_log_event("Healed 30.")
	_update_ui()


func _use_stamina() -> void:
	stats.modify_value(&"stamina", -15.0)
	_log_event("Used 15 stamina.")
	_update_ui()


func _use_mana() -> void:
	stats.modify_value(&"mana", -10.0)
	_log_event("Used 10 mana.")
	_update_ui()


func _gain_xp(amount: int) -> void:
	leveling.add_xp(amount)
	_update_ui()


func _spend(stat_name: StringName) -> void:
	if not leveling.spend_stat_point(stat_name):
		_log_event("No stat points to spend. Gain some XP first.")
	_update_ui()


## A source-tagged modifier: equipping sets it, unequipping clears exactly this
## source and nothing else.
func _set_sword(on: bool) -> void:
	if on:
		stats.set_modifier(&"strength", IRON_SWORD, 20.0)
		_log_event("Equipped the iron sword: +20 strength.")
	else:
		stats.clear_source(IRON_SWORD)
		_log_event("Unequipped the iron sword.")
	_update_ui()


func _set_blessing(on: bool) -> void:
	if on:
		stats.set_modifier(&"health", BLESSING, 0.0, 0.25)
		_log_event("Blessed: +25% max health.")
	else:
		stats.clear_source(BLESSING)
		_log_event("The blessing fades.")
	_update_ui()


func _rest() -> void:
	stats.restore_all_stats()
	_log_event("Rested. Every pool is full.")
	_update_ui()


## Snapshots hold base and current values plus level, XP and points. Modifiers
## are not saved: they come back when the equipment that grants them does.
func _save() -> void:
	_saved = {
		"stats": stats.get_stats_snapshot(),
		"leveling": leveling.get_save_data(),
	}
	%LoadButton.disabled = false
	_log_event("Saved a snapshot.")
	_update_ui()


func _load() -> void:
	if _saved.is_empty():
		return
	stats.load_stats_snapshot(_saved["stats"])
	leveling.load_save_data(_saved["leveling"])
	_log_event("Loaded the snapshot.")
	_update_ui()


# --- Signals from the system ------------------------------------------------

func _on_stat_depleted(stat_name: StringName) -> void:
	if stat_name == &"health":
		_log_event("[color=#ff6b6b]Health hit 0. Press Rest to recover.[/color]")
	else:
		_log_event("Out of %s." % stat_name)


func _on_xp_gained(amount: int, _total: int) -> void:
	_log_event("+%d XP." % amount)


func _on_level_up(new_level: int, points: int) -> void:
	_log_event("[color=gold]Level up! Now level %d, +%d stat points.[/color]" % [new_level, points])


func _on_stat_point_spent(stat_name: StringName, remaining: int) -> void:
	_log_event("+1 %s. %d points left." % [String(stat_name).capitalize(), remaining])


# --- Character sheet ----------------------------------------------------------

func _log_event(text: String) -> void:
	_log.push_front(text)
	if _log.size() > LOG_LINES:
		_log.resize(LOG_LINES)


func _update_ui() -> void:
	var t := "[font_size=20][b]Character Sheet[/b][/font_size]\n\n"
	t += "[color=gold]Level %d[/color]    XP %d / %d\n" % [
		leveling.current_level, leveling.current_xp, leveling.get_xp_to_next_level()]
	t += _bar(leveling.get_level_progress(), "gold") + "\n"
	t += "Stat points: [color=lime]%d[/color]\n\n" % leveling.available_stat_points

	t += "[color=#7fd4ff]RESOURCES[/color]\n[table=3]"
	t += _pool_line(&"health", "#ff6b6b")
	t += _pool_line(&"stamina", "#7bd88f")
	t += _pool_line(&"mana", "#6fa8ff")
	t += "[/table]\n"

	t += "\n[color=#7fd4ff]ATTRIBUTES[/color]\n"
	for attribute: StringName in [&"strength", &"dexterity", &"vitality"]:
		t += _attribute_line(attribute)

	t += "\n[color=#7fd4ff]MODIFIERS[/color]\n"
	var any_modifier := false
	for stat_name: StringName in stats.get_all_stat_names():
		var mods := stats.get_stat(stat_name).get_modifiers()
		for source: StringName in mods:
			any_modifier = true
			t += "%s %s [color=gray](%s)[/color]\n" % [
				_modifier_text(mods[source]), String(stat_name).capitalize(), source]
	if not any_modifier:
		t += "[color=gray]None[/color]\n"

	t += "\n[color=#7fd4ff]EVENTS[/color]\n"
	for i in _log.size():
		t += ("%s\n" % _log[i]) if i == 0 else ("[color=gray]%s[/color]\n" % _log[i])
	sheet.text = t


func _bar(ratio: float, color: String, width: int = 16) -> String:
	var filled := clampi(roundi(ratio * width), 0, width)
	return "[color=%s]%s[/color][color=#3a3a46]%s[/color]" % [
		color, "█".repeat(filled), "█".repeat(width - filled)]


func _pool_line(stat_name: StringName, color: String) -> String:
	var stat := stats.get_stat(stat_name)
	if not stat:
		return ""
	return "[cell]%s  [/cell][cell]%s  [/cell][cell]%.0f / %.0f[/cell]" % [
		String(stat_name).capitalize(), _bar(stat.get_ratio(), color, 12), stat.current_value, stat.max_computed]


## Attributes read through get_value(), which includes every modifier.
func _attribute_line(stat_name: StringName) -> String:
	var stat := stats.get_stat(stat_name)
	if not stat:
		return ""
	var value := stats.get_value(stat_name)
	if value > stat.base_value:
		return "%s: [color=lime]%.0f[/color] [color=gray](base %.0f)[/color]\n" % [
			String(stat_name).capitalize(), value, stat.base_value]
	return "%s: %.0f\n" % [String(stat_name).capitalize(), value]


func _modifier_text(mod: Dictionary) -> String:
	var parts: Array[String] = []
	if not is_zero_approx(mod.get("flat", 0.0)):
		parts.append("%+.0f" % mod["flat"])
	if not is_zero_approx(mod.get("percent", 0.0)):
		parts.append("%+.0f%%" % (mod["percent"] * 100.0))
	return " ".join(parts)
