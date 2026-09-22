extends Node3D

const DuelFighterScript = preload("res://scripts/fighter.gd")
const DuelRacerScript = preload("res://scripts/racer.gd")
const SimpleSfxScript = preload("res://scripts/sfx.gd")

const MODE_NONE := 0
const MODE_FIGHT := 1
const MODE_RACE := 2

var fighters := [
	{"name":"БЛИЦ", "color":Color("36b8ff")},
	{"name":"ФЛЭЙМ", "color":Color("ff5c5c")},
	{"name":"ЛАЙМ", "color":Color("7ee86f")},
	{"name":"ВАЙОЛЕТ", "color":Color("b06cff")},
	{"name":"САННИ", "color":Color("ffc94a")},
	{"name":"НЕОН", "color":Color("38f0d0")}
]

var fighter_index := 0
var remote_fighter_index := 1
var current_mode := MODE_NONE
var multiplayer_mode := false
var game_over := false
var world_root: Node3D
var ui_root: Control
var hud_root: Control
var camera: Camera3D
var local_fighter: DuelFighter
var remote_fighter: DuelFighter
var local_racer: DuelRacer
var remote_racer: DuelRacer
var sfx: SimpleSfx
var status_label: Label
var ip_edit: LineEdit
var host_start_box: VBoxContainer
var left_down := false
var right_down := false
var up_down := false
var back_down := false
var boost_down := false
var sync_accum := 0.0
var settings_low_quality := true

func _ready() -> void:
	_ensure_input_actions()
	sfx = SimpleSfxScript.new()
	add_child(sfx)
	NetworkManager.status_changed.connect(_on_network_status)
	NetworkManager.connection_changed.connect(_on_network_connection)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	show_main_menu()

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("attack", [KEY_SPACE, KEY_F])
	_add_key_action("boost", [KEY_SPACE, KEY_E])

func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if current_mode == MODE_FIGHT and is_instance_valid(local_fighter):
		local_fighter.touch_input = Vector2(float(right_down) - float(left_down), float(back_down) - float(up_down))
		_update_fight_camera(delta)
	elif current_mode == MODE_RACE and is_instance_valid(local_racer):
		local_racer.touch_axis = float(right_down) - float(left_down)
		local_racer.touch_boost = boost_down
		_update_race_camera(delta)
	if multiplayer_mode and NetworkManager.connected and current_mode != MODE_NONE:
		sync_accum += delta
		if sync_accum >= 0.05:
			sync_accum = 0.0
			_send_network_state()

func show_main_menu() -> void:
	_stop_game()
	_clear_ui()
	_build_menu_background()
	var panel := _panel(Vector2(500, 590), Vector2(390, 65))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 26)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := _label("DUEL DASH 3D", 42, true)
	box.add_child(title)
	box.add_child(_label("Аркадная 3D-игра для Android", 18, true, Color("9fc8ff")))
	var hero := _label("Боец: %s" % fighters[fighter_index].name, 24, true, fighters[fighter_index].color)
	box.add_child(hero)
	box.add_child(_button("🤖 ИГРАТЬ С БОТОМ", func(): _show_mode_select(false), Color("2765d8")))
	box.add_child(_button("📶 ИГРА ПО WI-FI", show_network_menu, Color("18a66b")))
	box.add_child(_button("👤 ВЫБОР БОЙЦА", show_fighter_select, Color("8b4bd8")))
	box.add_child(_button("⚙ НАСТРОЙКИ", show_settings, Color("555d73")))
	box.add_child(_label("WASD/стрелки + Space на ПК. На Android есть экранные кнопки.", 14, true, Color("aab4cc")))

func show_fighter_select() -> void:
	_clear_ui()
	_build_menu_background()
	var panel := _panel(Vector2(820, 560), Vector2(230, 78))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label("ВЫБОР БОЙЦА", 34, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for i in fighters.size():
		var idx := i
		var b := _button("●  %s" % fighters[i].name, func(): _select_fighter(idx), fighters[i].color.darkened(0.25))
		b.custom_minimum_size = Vector2(235, 88)
		grid.add_child(b)
	box.add_child(_button("← НАЗАД", show_main_menu, Color("4f586e")))

func _select_fighter(index: int) -> void:
	fighter_index = index
	if NetworkManager.connected and not NetworkManager.is_host:
		rpc_set_client_fighter.rpc_id(1, fighter_index)
	sfx.click()
	show_main_menu()

func show_settings() -> void:
	_clear_ui()
	_build_menu_background()
	var panel := _panel(Vector2(600, 430), Vector2(340, 140))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_label("НАСТРОЙКИ", 34, true))
	var sound_button := _button("Звуки: %s" % ("ВКЛ" if sfx.enabled else "ВЫКЛ"), func(): _toggle_sound(), Color("2765d8"))
	sound_button.name = "SoundButton"
	box.add_child(sound_button)
	var quality_button := _button("Графика: %s" % ("ЭКОНОМ" if settings_low_quality else "КАЧЕСТВО"), func(): _toggle_quality(), Color("18a66b"))
	quality_button.name = "QualityButton"
	box.add_child(quality_button)
	box.add_child(_label("Эконом-режим рекомендуется для бюджетных Android-телефонов.", 16, true, Color("aab4cc")))
	box.add_child(_button("← НАЗАД", show_main_menu, Color("4f586e")))

func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	show_settings()

func _toggle_quality() -> void:
	settings_low_quality = not settings_low_quality
	show_settings()

func _show_mode_select(networked: bool) -> void:
	_clear_ui()
	_build_menu_background()
	var panel := _panel(Vector2(620, 480), Vector2(330, 115))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(_label("ВЫБЕРИТЕ РЕЖИМ", 34, true))
	var fight_cb := func():
		if networked:
			_host_start_network_game(MODE_FIGHT)
		else:
			start_fight(false)
	var race_cb := func():
		if networked:
			_host_start_network_game(MODE_RACE)
		else:
			start_race(false)
	box.add_child(_button("🥊 3D ДРАКА", fight_cb, Color("cf4f53")))
	box.add_child(_button("🏁 3D ГОНКА", race_cb, Color("2765d8")))
	box.add_child(_button("← НАЗАД", show_network_menu if networked else show_main_menu, Color("4f586e")))

func show_network_menu() -> void:
	_stop_game()
	_clear_ui()
	_build_menu_background()
	var panel := _panel(Vector2(720, 575), Vector2(280, 72))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label("WI-FI ЛОББИ", 34, true))
	box.add_child(_label("Оба телефона должны быть в одной Wi-Fi сети или один может раздать точку доступа.", 15, true, Color("aab4cc")))
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP хоста, например 192.168.1.15"
	ip_edit.text = "192.168.1.15"
	ip_edit.custom_minimum_size = Vector2(0, 52)
	box.add_child(ip_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_button("СОЗДАТЬ ХОСТ", func(): NetworkManager.host_game(), Color("18a66b")))
	row.add_child(_button("ПОДКЛЮЧИТЬСЯ", func(): NetworkManager.join_game(ip_edit.text), Color("2765d8")))
	status_label = _label("IP этого телефона: %s : %d" % [NetworkManager.get_local_ipv4(), NetworkManager.PORT], 17, true, Color("9fc8ff"))
	box.add_child(status_label)
	host_start_box = VBoxContainer.new()
	host_start_box.add_theme_constant_override("separation", 10)
	box.add_child(host_start_box)
	_refresh_network_controls()
	box.add_child(_button("🤖 ИГРАТЬ БЕЗ ВТОРОГО ТЕЛЕФОНА", func(): _show_mode_select(false), Color("8b4bd8")))
	box.add_child(_button("← НАЗАД", func(): NetworkManager.stop(); show_main_menu(), Color("4f586e")))

func _refresh_network_controls() -> void:
	if not is_instance_valid(host_start_box):
		return
	for c in host_start_box.get_children():
		c.queue_free()
	if NetworkManager.connected and NetworkManager.is_host:
		host_start_box.add_child(_label("Второй игрок готов. Выберите игру:", 18, true, Color("70f0b5")))
		host_start_box.add_child(_button("🥊 НАЧАТЬ 3D ДРАКУ", func(): _host_start_network_game(MODE_FIGHT), Color("cf4f53")))
		host_start_box.add_child(_button("🏁 НАЧАТЬ 3D ГОНКУ", func(): _host_start_network_game(MODE_RACE), Color("2765d8")))
	elif NetworkManager.connected:
		host_start_box.add_child(_label("Подключено. Ждём, когда хост выберет игру...", 18, true, Color("70f0b5")))
	elif NetworkManager.is_host:
		host_start_box.add_child(_label("Хост создан. Сообщите второму телефону IP выше.", 17, true, Color("ffc968")))

func _on_network_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text
	_refresh_network_controls()

func _on_network_connection(_value: bool) -> void:
	_refresh_network_controls()

func _on_peer_joined(_peer_id: int) -> void:
	if NetworkManager.is_host:
		rpc_host_fighter.rpc(fighter_index)

@rpc("any_peer", "call_remote", "reliable")
func rpc_set_client_fighter(index: int) -> void:
	if NetworkManager.is_host:
		remote_fighter_index = clampi(index, 0, fighters.size() - 1)

@rpc("authority", "call_remote", "reliable")
func rpc_host_fighter(index: int) -> void:
	remote_fighter_index = clampi(index, 0, fighters.size() - 1)

func _host_start_network_game(mode: int) -> void:
	if not NetworkManager.is_host or not NetworkManager.connected:
		return
	rpc_start_game.rpc(mode, fighter_index, remote_fighter_index)
	_start_mode(mode, true, fighter_index, remote_fighter_index)

@rpc("authority", "call_remote", "reliable")
func rpc_start_game(mode: int, host_fighter: int, client_fighter: int) -> void:
	_start_mode(mode, true, host_fighter, client_fighter)

func _start_mode(mode: int, networked: bool, host_fighter: int = -1, client_fighter: int = -1) -> void:
	if networked:
		multiplayer_mode = true
		var my_id := multiplayer.get_unique_id()
		if my_id == 1:
			fighter_index = host_fighter
			remote_fighter_index = client_fighter
		else:
			fighter_index = client_fighter
			remote_fighter_index = host_fighter
	if mode == MODE_FIGHT:
		start_fight(networked)
	elif mode == MODE_RACE:
		start_race(networked)

func start_fight(networked: bool) -> void:
	_stop_game()
	_clear_ui()
	multiplayer_mode = networked
	current_mode = MODE_FIGHT
	game_over = false
	_build_fight_world()
	var me_host_side := not networked or multiplayer.get_unique_id() == 1
	local_fighter = DuelFighterScript.new()
	local_fighter.setup(fighters[fighter_index].color, true, false, false)
	local_fighter.position = Vector3(-4 if me_host_side else 4, 0, 0)
	world_root.add_child(local_fighter)
	local_fighter.attack_requested.connect(_on_fighter_attack)
	remote_fighter = DuelFighterScript.new()
	remote_fighter.setup(fighters[remote_fighter_index].color, false, not networked, networked)
	remote_fighter.position = Vector3(4 if me_host_side else -4, 0, 0)
	world_root.add_child(remote_fighter)
	remote_fighter.attack_requested.connect(_on_fighter_attack)
	if not networked:
		remote_fighter.bot_target = local_fighter
		local_fighter.bot_target = remote_fighter
	_build_fight_hud()
	sfx.click()

func _on_fighter_attack(attacker: DuelFighter) -> void:
	if game_over:
		return
	var target: DuelFighter = remote_fighter if attacker == local_fighter else local_fighter
	if not is_instance_valid(target):
		return
	var dist := attacker.global_position.distance_to(target.global_position)
	if dist <= 2.7:
		target.take_hit(attacker.global_position, attacker.damage)
		sfx.hit()
		if multiplayer_mode and attacker == local_fighter:
			rpc_take_damage.rpc(attacker.global_position, attacker.damage)
		_check_fight_end()

@rpc("any_peer", "call_remote", "reliable")
func rpc_take_damage(attacker_pos: Vector3, amount: int) -> void:
	if current_mode != MODE_FIGHT or not is_instance_valid(local_fighter):
		return
	local_fighter.take_hit(attacker_pos, amount)
	sfx.hit()
	_check_fight_end()

func _check_fight_end() -> void:
	if game_over or not is_instance_valid(local_fighter) or not is_instance_valid(remote_fighter):
		return
	if local_fighter.hp <= 0:
		_finish_game("ПОРАЖЕНИЕ")
	elif remote_fighter.hp <= 0:
		_finish_game("ПОБЕДА!")

func start_race(networked: bool) -> void:
	_stop_game()
	_clear_ui()
	multiplayer_mode = networked
	current_mode = MODE_RACE
	game_over = false
	_build_race_world()
	var me_host_side := not networked or multiplayer.get_unique_id() == 1
	local_racer = DuelRacerScript.new()
	local_racer.setup(fighters[fighter_index].color, true, false, false)
	local_racer.position = Vector3(-2.3 if me_host_side else 2.3, 0, 34)
	world_root.add_child(local_racer)
	local_racer.finished.connect(_on_racer_finished)
	remote_racer = DuelRacerScript.new()
	remote_racer.setup(fighters[remote_fighter_index].color, false, not networked, networked)
	remote_racer.position = Vector3(2.3 if me_host_side else -2.3, 0, 34)
	world_root.add_child(remote_racer)
	remote_racer.finished.connect(_on_racer_finished)
	_build_race_hud()
	sfx.click()

func _on_racer_finished(racer: DuelRacer) -> void:
	if game_over:
		return
	if racer == local_racer:
		if multiplayer_mode:
			rpc_race_winner.rpc(multiplayer.get_unique_id())
		_finish_game("ПОБЕДА В ГОНКЕ!")
	else:
		_finish_game("СОПЕРНИК ФИНИШИРОВАЛ")

@rpc("any_peer", "call_remote", "reliable")
func rpc_race_winner(_winner_peer: int) -> void:
	if current_mode == MODE_RACE and not game_over:
		_finish_game("СОПЕРНИК ФИНИШИРОВАЛ")

func _send_network_state() -> void:
	if current_mode == MODE_FIGHT and is_instance_valid(local_fighter):
		rpc_fight_state.rpc(local_fighter.global_position, local_fighter.rotation.y, local_fighter.attack_anim > 0.0)
	elif current_mode == MODE_RACE and is_instance_valid(local_racer):
		rpc_race_state.rpc(local_racer.global_position, local_racer.rotation.y)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_fight_state(pos: Vector3, yaw: float, attacking: bool) -> void:
	if current_mode == MODE_FIGHT and is_instance_valid(remote_fighter):
		remote_fighter.apply_remote_state(pos, yaw, attacking)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_race_state(pos: Vector3, yaw: float) -> void:
	if current_mode == MODE_RACE and is_instance_valid(remote_racer):
		remote_racer.apply_remote_state(pos, yaw)

func _finish_game(text: String) -> void:
	if game_over:
		return
	game_over = true
	left_down = false
	right_down = false
	up_down = false
	back_down = false
	boost_down = false
	sfx.win()
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.06, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(overlay)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 260)
	box.position = Vector2(380, 200)
	box.add_theme_constant_override("separation", 16)
	overlay.add_child(box)
	box.add_child(_label(text, 42, true, Color("ffd467")))
	var replay_cb := func():
		if current_mode == MODE_FIGHT:
			start_fight(false if not multiplayer_mode else true)
		else:
			start_race(false if not multiplayer_mode else true)
	if not multiplayer_mode:
		box.add_child(_button("ЕЩЁ РАЗ", replay_cb, Color("2765d8")))
	box.add_child(_button("ГЛАВНОЕ МЕНЮ", func(): NetworkManager.stop(); show_main_menu(), Color("4f586e")))

func _build_fight_world() -> void:
	_create_world_base(Color("18213d"))
	_create_ground(Vector3(34, 0.5, 24), Color("26375b"), Vector3(0, -0.25, 0))
	_create_wall(Vector3(34, 2.0, 0.6), Vector3(0, 1.0, -12), Color("5e3e8b"))
	_create_wall(Vector3(34, 2.0, 0.6), Vector3(0, 1.0, 12), Color("5e3e8b"))
	_create_wall(Vector3(0.6, 2.0, 24), Vector3(-17, 1.0, 0), Color("315fa9"))
	_create_wall(Vector3(0.6, 2.0, 24), Vector3(17, 1.0, 0), Color("315fa9"))
	for p in [Vector3(-10,0,-7), Vector3(10,0,-7), Vector3(-10,0,7), Vector3(10,0,7)]:
		var lamp := OmniLight3D.new()
		lamp.position = p + Vector3(0, 4.5, 0)
		lamp.light_color = Color("6aa8ff")
		lamp.omni_range = 10.0
		lamp.light_energy = 2.2 if not settings_low_quality else 1.2
		world_root.add_child(lamp)
	camera.position = Vector3(0, 15.5, 18.0)
	camera.look_at(Vector3(0, 1.0, 0))

func _build_race_world() -> void:
	_create_world_base(Color("12213a"))
	_create_ground(Vector3(16, 0.5, 270), Color("303744"), Vector3(0, -0.25, -93))
	_create_ground(Vector3(0.22, 0.03, 270), Color("f4d04d"), Vector3(0, 0.02, -93))
	_create_wall(Vector3(0.5, 1.0, 270), Vector3(-7.8, 0.5, -93), Color("4d77b9"))
	_create_wall(Vector3(0.5, 1.0, 270), Vector3(7.8, 0.5, -93), Color("4d77b9"))
	var obstacle_positions := [
		Vector3(-3.7, 0.75, 3), Vector3(2.8,0.75,-27), Vector3(-1.0,0.75,-58),
		Vector3(4.2,0.75,-91), Vector3(-4.4,0.75,-124), Vector3(1.4,0.75,-155), Vector3(-2.5,0.75,-186)
	]
	for i in obstacle_positions.size():
		_create_wall(Vector3(2.3, 1.5, 1.2), obstacle_positions[i], Color("d65757") if i % 2 == 0 else Color("e0a542"))
	_create_ground(Vector3(15, 0.05, 1.2), Color("f8f8f8"), Vector3(0, 0.03, -220))
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		_create_ground(Vector3(1.0, 0.06, 1.25), Color("17191f") if int(x) % 4 == 1 else Color("ffffff"), Vector3(x, 0.05, -220))
	camera.position = Vector3(0, 8.0, 48.0)
	camera.look_at(Vector3(0, 1.2, 26.0))

func _create_world_base(bg: Color) -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8ca9d7")
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = not settings_low_quality
	world_root.add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62.0
	world_root.add_child(camera)

func _create_ground(size: Vector3, color: Color, pos: Vector3) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mesh_i.material_override = mat
	mesh_i.position = pos
	world_root.add_child(mesh_i)
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	world_root.add_child(body)

func _create_wall(size: Vector3, pos: Vector3, color: Color) -> void:
	_create_ground(size, color, pos)

func _update_fight_camera(delta: float) -> void:
	if not is_instance_valid(local_fighter) or not is_instance_valid(remote_fighter) or not is_instance_valid(camera):
		return
	var mid := (local_fighter.global_position + remote_fighter.global_position) * 0.5
	var dist := local_fighter.global_position.distance_to(remote_fighter.global_position)
	var desired := mid + Vector3(0, 10.5 + dist * 0.18, 13.5 + dist * 0.30)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 3.8))
	camera.look_at(mid + Vector3(0, 1.1, 0))

func _update_race_camera(delta: float) -> void:
	if not is_instance_valid(local_racer) or not is_instance_valid(camera):
		return
	var desired := local_racer.global_position + Vector3(0, 7.2, 12.8)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 4.8))
	camera.look_at(local_racer.global_position + Vector3(0, 1.2, -8.0))

func _build_fight_hud() -> void:
	_build_common_hud()
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 18
	top.custom_minimum_size.y = 54
	hud_root.add_child(top)
	var hp_left := _label("ВАШЕ HP", 18, false)
	hp_left.name = "HpLeft"
	hp_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hp_left)
	var mode := _label("3D ДРАКА", 22, true, Color("ffd467"))
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mode)
	var hp_right := _label("СОПЕРНИК HP", 18, false)
	hp_right.name = "HpRight"
	hp_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hp_right)
	local_fighter.health_changed.connect(func(v): hp_left.text = "ВАШЕ HP: %d" % v)
	remote_fighter.health_changed.connect(func(v): hp_right.text = "СОПЕРНИК HP: %d" % v)
	hp_left.text = "ВАШЕ HP: 100"
	hp_right.text = "СОПЕРНИК HP: 100"
	_build_fight_controls()

func _build_race_hud() -> void:
	_build_common_hud()
	var label := _label("🏁 3D ГОНКА  •  Space/BOOST = ускорение", 20, true, Color("ffd467"))
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 18
	label.offset_left = 220
	label.offset_right = -220
	hud_root.add_child(label)
	_build_race_controls()

func _build_common_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud_root)
	var back := _button("☰", func(): NetworkManager.stop(); show_main_menu(), Color(0.16,0.18,0.24,0.88))
	back.position = Vector2(18, 16)
	back.custom_minimum_size = Vector2(70, 52)
	hud_root.add_child(back)

func _build_fight_controls() -> void:
	var left := _hold_button("←", Vector2(30, 590), func(v): left_down = v)
	var right := _hold_button("→", Vector2(180, 590), func(v): right_down = v)
	var up := _hold_button("↑", Vector2(105, 515), func(v): up_down = v)
	var down := _hold_button("↓", Vector2(105, 615), func(v): back_down = v)
	var attack_cb := func():
		if is_instance_valid(local_fighter):
			local_fighter.try_attack()
	var attack := _button("УДАР", attack_cb, Color(0.78,0.18,0.22,0.88))
	attack.position = Vector2(1050, 560)
	attack.custom_minimum_size = Vector2(180, 120)
	attack.add_theme_font_size_override("font_size", 26)
	for b in [left, right, up, down, attack]:
		hud_root.add_child(b)

func _build_race_controls() -> void:
	var left := _hold_button("←", Vector2(45, 585), func(v): left_down = v)
	var right := _hold_button("→", Vector2(200, 585), func(v): right_down = v)
	var boost := _hold_button("BOOST", Vector2(1020, 570), func(v): boost_down = v, Color(0.92,0.56,0.12,0.90))
	boost.custom_minimum_size = Vector2(210, 115)
	for b in [left, right, boost]:
		hud_root.add_child(b)

func _hold_button(text: String, pos: Vector2, callback: Callable, color: Color = Color(0.16,0.26,0.45,0.82)) -> Button:
	var b := _button(text, func(): pass, color)
	b.position = pos
	b.custom_minimum_size = Vector2(125, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.button_down.connect(func(): callback.call(true))
	b.button_up.connect(func(): callback.call(false))
	return b

func _stop_game() -> void:
	current_mode = MODE_NONE
	game_over = false
	left_down = false
	right_down = false
	up_down = false
	back_down = false
	boost_down = false
	local_fighter = null
	remote_fighter = null
	local_racer = null
	remote_racer = null
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null
	if is_instance_valid(hud_root):
		hud_root.queue_free()
	hud_root = null

func _clear_ui() -> void:
	if is_instance_valid(ui_root):
		ui_root.queue_free()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)

func _build_menu_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color("09101f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(bg)
	for i in 12:
		var stripe := ColorRect.new()
		stripe.color = Color(0.08 + i * 0.004, 0.17, 0.31 + i * 0.012, 0.18)
		stripe.position = Vector2(-150 + i * 120, -100)
		stripe.size = Vector2(72, 950)
		stripe.rotation = -0.28
		bg.add_child(stripe)
	var tag := _label("BATTLE  •  RACE  •  BOT  •  WI-FI", 18, true, Color("6e8dbd"))
	tag.position = Vector2(395, 655)
	ui_root.add_child(tag)

func _panel(size: Vector2, pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.13, 0.96)
	sb.border_color = Color("355a9a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0,0,0,0.38)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	ui_root.add_child(p)
	return p

func _button(text: String, callback: Callable, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.14)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func(): sfx.click(); callback.call())
	return b

func _label(text: String, size: int, center: bool = false, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
