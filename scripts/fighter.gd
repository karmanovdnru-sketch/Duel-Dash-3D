extends CharacterBody3D
class_name DuelFighter

signal attack_requested(fighter: DuelFighter)
signal health_changed(value: int)

var controlled := false
var bot := false
var remote := false
var hp := 100
var speed := 7.0
var damage := 18
var attack_cooldown := 0.0
var attack_anim := 0.0
var hurt_anim := 0.0
var touch_input := Vector2.ZERO
var bot_target: DuelFighter
var fighter_color := Color(0.2, 0.7, 1.0)
var walk_phase := 0.0
var visual := Node3D.new()
var body_mat := StandardMaterial3D.new()
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var head: MeshInstance3D

func setup(color: Color, is_controlled: bool, is_bot: bool = false, is_remote: bool = false) -> void:
	fighter_color = color
	controlled = is_controlled
	bot = is_bot
	remote = is_remote

func _ready() -> void:
	_build_visual()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_anim = maxf(0.0, attack_anim - delta)
	hurt_anim = maxf(0.0, hurt_anim - delta)
	if remote:
		velocity = Vector3.ZERO
		_animate(delta, Vector2.ZERO)
		return
	var input_dir := Vector2.ZERO
	if bot:
		input_dir = _bot_input()
	elif controlled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_input
		input_dir = input_dir.limit_length(1.0)
		if Input.is_action_just_pressed("attack"):
			try_attack()
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	if input_dir.length() > 0.08:
		rotation.y = lerp_angle(rotation.y, atan2(-input_dir.x, -input_dir.y), minf(1.0, delta * 11.0))
	_animate(delta, input_dir)

func _bot_input() -> Vector2:
	if not is_instance_valid(bot_target):
		return Vector2.ZERO
	var d := bot_target.global_position - global_position
	var flat := Vector2(d.x, d.z)
	if flat.length() < 2.35:
		try_attack()
		return -flat.normalized() * 0.12
	return flat.normalized()

func try_attack() -> void:
	if attack_cooldown > 0.0 or hp <= 0:
		return
	attack_cooldown = 0.62
	attack_anim = 0.30
	attack_requested.emit(self)

func take_hit(from_position: Vector3, amount: int = 18) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	hurt_anim = 0.18
	var push := global_position - from_position
	push.y = 0.0
	if push.length() > 0.05:
		push = push.normalized()
		velocity += push * 5.0
	health_changed.emit(hp)

func apply_remote_state(pos: Vector3, yaw: float, is_attacking: bool) -> void:
	global_position = global_position.lerp(pos, 0.42)
	rotation.y = lerp_angle(rotation.y, yaw, 0.45)
	if is_attacking:
		attack_anim = maxf(attack_anim, 0.12)

func _build_visual() -> void:
	visual.name = "CartoonVisual"
	add_child(visual)
	body_mat.albedo_color = fighter_color
	body_mat.roughness = 0.68
	body_mat.metallic = 0.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = fighter_color.darkened(0.38)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(1.0, 0.72, 0.52)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.03, 0.04, 0.06)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.62
	torso_mesh.height = 1.15
	torso.mesh = torso_mesh
	torso.material_override = body_mat
	torso.position = Vector3(0, 1.35, 0)
	visual.add_child(torso)

	head = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.52
	hm.height = 1.04
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 2.24, 0)
	visual.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.54
	hair_mesh.height = 0.55
	hair.mesh = hair_mesh
	hair.material_override = dark
	hair.position = Vector3(0, 2.46, 0.04)
	hair.scale = Vector3(1.0, 0.62, 1.0)
	visual.add_child(hair)

	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.075
		em.height = 0.15
		e.mesh = em
		e.material_override = eye
		e.position = Vector3(0.17 * sx, 2.29, -0.46)
		visual.add_child(e)

	left_arm = _limb(Vector3(-0.82, 1.48, 0), body_mat)
	right_arm = _limb(Vector3(0.82, 1.48, 0), body_mat)
	left_leg = _limb(Vector3(-0.30, 0.48, 0), dark)
	right_leg = _limb(Vector3(0.30, 0.48, 0), dark)
	left_arm.rotation.z = -0.10
	right_arm.rotation.z = 0.10

func _limb(pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.20
	mesh.height = 0.92
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	visual.add_child(n)
	return n

func _animate(delta: float, input_dir: Vector2) -> void:
	if input_dir.length() > 0.05 and attack_anim <= 0.0:
		walk_phase += delta * 11.0
	else:
		walk_phase = lerpf(walk_phase, 0.0, delta * 4.0)
	var swing := sin(walk_phase) * 0.58 if input_dir.length() > 0.05 else 0.0
	left_arm.rotation.x = swing
	right_arm.rotation.x = -swing
	left_leg.rotation.x = -swing
	right_leg.rotation.x = swing
	if attack_anim > 0.0:
		var p := 1.0 - attack_anim / 0.30
		right_arm.rotation.x = -1.65 * sin(p * PI)
		right_arm.rotation.z = 0.55 * sin(p * PI)
	if hurt_anim > 0.0:
		visual.rotation.z = sin(hurt_anim * 55.0) * 0.08
	else:
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, minf(1.0, delta * 12.0))
