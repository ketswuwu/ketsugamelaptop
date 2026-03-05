extends Control

@onready var bar: ProgressBar = $BossHealthBar
@onready var name_label: Label = get_node_or_null("BossName")

var boss: Node = null

func show_for_boss(boss_node: Node, boss_name: String = "Boss") -> void:
	# Disconnect from previous boss (if any)
	if is_instance_valid(boss):
		if boss.is_connected("boss_hp_changed", _on_boss_hp_changed):
			boss.disconnect("boss_hp_changed", _on_boss_hp_changed)
		if boss.is_connected("boss_died", _on_boss_died):
			boss.disconnect("boss_died", _on_boss_died)

	boss = boss_node

	if name_label:
		name_label.text = boss_name

	visible = true

	# Connect to new boss
	boss.connect("boss_hp_changed", _on_boss_hp_changed)
	boss.connect("boss_died", _on_boss_died)

	# If boss already has hp variables, you can initialize immediately (optional)
	if "hp" in boss and "max_health" in boss:
		_on_boss_hp_changed(boss.hp, boss.max_health)

func hide_bar() -> void:
	visible = false

func _on_boss_hp_changed(current: int, maxv: int) -> void:
	bar.max_value = maxv
	bar.value = clamp(current, 0, maxv)

func _on_boss_died() -> void:
	hide_bar()
