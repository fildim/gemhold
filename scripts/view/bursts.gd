extends Node2D
## Short bursts of particles over the board: dust and scraps where a hero falls, dust when a
## tower goes up, sparks for loot picked up, debris from a meteor. Listens to GameSim.burst.
## CPUParticles2D behaves the same on web and Android under the Compatibility renderer.
## Emitters are pooled and capped (MAX_EMITTERS × at most MAX_AMOUNT particles); when every one
## is busy the oldest is reused, so a huge fight never piles up particles.

const T := 64.0
const MAX_EMITTERS := 20
const MAX_AMOUNT := 16

var _pool: Array[CPUParticles2D] = []
var _next := 0
var _dot: Texture2D
var _tunic := {}


func setup(sim: GameSim, tunic: Dictionary) -> void:
	_tunic = tunic
	sim.burst.connect(_on_burst)
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 16
		tex.height = 16
		_dot = tex
	for p in _pool:
		p.emitting = false


func _emitter() -> CPUParticles2D:
	if _pool.size() < MAX_EMITTERS:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.local_coords = false
		p.texture = _dot
		add_child(p)
		_pool.append(p)
		return p
	for i in _pool.size():
		var p := _pool[(_next + i) % _pool.size()]
		if not p.emitting:
			_next = (_next + i + 1) % _pool.size()
			return p
	var oldest := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return oldest


func _shoot(at: Vector2, amount: int, life: float, col: Color, spread: float, speed: Vector2, gravity: float, size: Vector2, ramp_end := 0.0, up := false) -> void:
	var p := _emitter()
	p.emitting = false
	p.position = at
	p.amount = mini(amount, MAX_AMOUNT)
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1) if up else Vector2(1, 0)
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector2(0, gravity)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var fade := Gradient.new()
	fade.set_color(0, col)
	fade.set_color(1, Color(col, ramp_end))
	p.color_ramp = fade
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = T * 0.12
	p.restart()
	p.emitting = true


func _on_burst(kind: String, pos: Vector2, code: String) -> void:
	var at := pos * T
	match kind:
		"death":
			_shoot(at + Vector2(0, T * 0.1), 10, 0.55, Color(0.62, 0.55, 0.45, 0.75), 180.0, Vector2(25, 70), -20.0, Vector2(0.9, 1.6))
			_shoot(at, 6, 0.6, Color(_tunic.get(code, "9a7446")), 70.0, Vector2(60, 120), 260.0, Vector2(0.3, 0.55), 0.0, true)
		"build":
			_shoot(at + Vector2(0, T * 0.3), 12, 0.6, Color(0.7, 0.62, 0.5, 0.7), 180.0, Vector2(40, 90), -10.0, Vector2(0.8, 1.4))
		"pickup_coin":
			_shoot(at, 10, 0.45, Color("ffd86a"), 180.0, Vector2(50, 110), 60.0, Vector2(0.3, 0.6))
		"pickup_potion":
			_shoot(at, 10, 0.5, Color("b8a8ff"), 180.0, Vector2(40, 100), -40.0, Vector2(0.3, 0.6))
		"meteor":
			_shoot(at, 16, 0.8, Color(1, 0.55, 0.2, 0.95), 75.0, Vector2(140, 260), 420.0, Vector2(0.4, 0.8), 0.0, true)
			_shoot(at, 14, 1.0, Color(0.35, 0.3, 0.28, 0.7), 180.0, Vector2(30, 90), -25.0, Vector2(1.4, 2.4))
