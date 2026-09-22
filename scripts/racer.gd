extends CharacterBody3D
class_name DuelRacer

signal finished(racer: DuelRacer)

var controlled := false
var bot := false
var remote := false
var fighter_color := Color(0.2, 0.7, 1.0)
var touch_axis := 0.0
var touch_boost := false
var base_speed := 14.0
var current_speed := 14.0
var finished_race := false
var start_z := 34.0
var finish_z := -220.0
var visual := Node3D.new()
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var phase := 0.0

func setup(color: Color, is_controlled: bool, is_bot: bool = false, is_remote: bool = false) -> void:
	fighter_color = color
	controlled = is_controlled
	bot = is_bot
	remote = is_remote

func _ready() -> void:
	_build_visual()
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.75
	cs.shape = capsule
	cs.position.y = 0.95
	add_child(cs)

func _physics_process(delta: float) -> void:
	if remote or finished_race:
		velocity = Vector3.ZERO
		_animate(delta)
		return
	var axis := 0.0
	var boosting := false
	if controlled:
		axis = Input.get_axis("move_left", "move_right") + touch_axis
		axis = clampf(axis, -1.0, 1.0)
		boosting = Input.is_action_pressed("boost") or touch_boost
	elif bot:
		axis = sin(Time.get_ticks_msec() * 0.0018 + global_position.z * 0.03) * 0.45
		boosting = fmod(Time.get_ticks_msec() * 0.001, 4.0) > 2.9
	var target_speed := base_speed + (4.0 if boosting else 0.0) + (0.8 if bot else 0.0)
	current_speed = move_toward(current_speed, target_speed, delta * 6.0)
	velocity.x = axis * 7.5
	velocity.z = -current_speed
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	global_position.x = clampf(global_position.x, -6.2, 6.2)
	rotation.y = lerp_angle(rotation.y, -axis * 0.22, minf(1.0, delta * 5.0))
	_animate(delta)
	if global_position.z <= finish_z:
		finished_race = true
		finished.emit(self)

func progress() -> float:
	return clampf((start_z - global_position.z) / (start_z - finish_z), 0.0, 1.0)

func apply_remote_state(pos: Vector3, yaw: float) -> void:
	global_position = global_position.lerp(pos, 0.48)
	rotation.y = lerp_angle(rotation.y, yaw, 0.48)

func _build_visual() -> void:
	visual.name = "RunnerVisual"
	add_child(visual)
	var main_mat := StandardMaterial3D.new()
	main_mat.albedo_color = fighter_color
	var dark := StandardMaterial3D.new()
	dark.albedo_color = fighter_color.darkened(0.42)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(1.0, 0.72, 0.52)
	var torso := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.52
	bm.height = 1.05
	torso.mesh = bm
	torso.material_override = main_mat
	torso.position.y = 1.28
	visual.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.43
	hm.height = 0.86
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 2.05, 0)
	visual.add_child(head)
	left_arm = _limb(Vector3(-0.68, 1.40, 0), main_mat)
	right_arm = _limb(Vector3(0.68, 1.40, 0), main_mat)
	left_leg = _limb(Vector3(-0.25, 0.42, 0), dark)
	right_leg = _limb(Vector3(0.25, 0.42, 0), dark)

func _limb(pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.17
	mesh.height = 0.76
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	visual.add_child(n)
	return n

func _animate(delta: float) -> void:
	phase += delta * (12.0 + current_speed * 0.22)
	var s := sin(phase) * 0.78
	left_arm.rotation.x = s
	right_arm.rotation.x = -s
	left_leg.rotation.x = -s
	right_leg.rotation.x = s
	visual.position.y = abs(sin(phase * 2.0)) * 0.04
