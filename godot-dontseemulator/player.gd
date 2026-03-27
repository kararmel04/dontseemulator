extends RigidBody3D

# Durée en secondes entre 2 flashs
const COOLDOWN_FLASH: float = 2.0
# Durée en secondes d'un flash
const FLASH_LENGTH: float = .4

# Durée en secondes entre 2 visions
const COOLDOWN_VISION: float = 3.0
# Durée en secondes d'un vision
const VISION_LENGTH: float = FLASH_LENGTH

# Indice de luminosité quand le flash est activé
const GAMMA: float = 4.0

# Temps restant à attendre avant le prochain flash
var cooldown_flash: float = 0.0

# Temps avant prochain vision
var cooldown_vision: float = 0.0

# Indice de sensibilité de la souris
var mouse_sensitivity: float = 0.008

# Taux de mouvement de la souris (pour les mouvements de caméra)
var twist_input: float = 0.0
var pitch_input: float = 0.0

# Objets de la caméra du joueur
@onready var twist_pivot = $LocalTwistPivot
@onready var pitch_pivot = $LocalTwistPivot/LocalPitchPivot
@onready var camera_node = $LocalTwistPivot/LocalPitchPivot/LocalCamera

# Liste des positions flashées; type: liste de dico:
# {pos_x: float, pos_y: float, pos_z: float, rot_x: float, rot_y: float, nb_showed: int, cooldown: float}
var pos_list: Array[Dictionary] = []


# Permet d'activer la cam de son choix (true si on veut activer la globale, false si la locale)
func activate_cam(global: String):
		%GlobalTwistPivot/GlobalPitchPivot/GlobalCamera.current = (global == "global")
		camera_node.current = !(global == "global")
		
		$".".visible = !(global == "global")

# Appelé lorsque le noeuf entre en scène
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Appelé toutes les frames. delta est le temps depuis la dernière frame
func _process(delta: float) -> void:
	# Gestion des mouvements du joueurs
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	apply_central_force(twist_pivot.basis * input * 1200.0 * delta)
	
	# Gestion de la rotation de la caméra
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	
	# Limite de hauteur de la caméra
	pitch_pivot.rotation.x = clamp(
		pitch_pivot.rotation.x,
		-deg_to_rad(25),
		deg_to_rad(25)
	)
	
	# Reset mouvements de la souris
	twist_input = 0.0
	pitch_input = 0.0
	
	# Gestion de la flashlight (change la luminosité du monde si flashlight activée)
	var flashed := Input.is_action_pressed("flash")
	
	if (flashed and cooldown_flash <= 0.0):
		%WorldEnvironment.environment.tonemap_exposure = GAMMA
		cooldown_flash = COOLDOWN_FLASH
		
		activate_cam("local")
		
		pos_list.append({
			pos_x = camera_node.global_position.x,
			pos_y = camera_node.global_position.y,
			pos_z = camera_node.global_position.z,
			rot_x = pitch_pivot.rotation.x,
			rot_y = twist_pivot.rotation.y,
			nb_showed = 0,
			cooldown = COOLDOWN_VISION
		})
		
		cooldown_vision = COOLDOWN_VISION
	
	# Gestion de la souris (échap pour récup le controle de la souris)
	if (Input.is_action_just_pressed("ui_cancel")):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var has_vision := false
	
	# Gestion des visions
	for pos in pos_list:
		if (pos.cooldown <= 0.0):
			pos.nb_showed += 1
			%GlobalTwistPivot.global_position = Vector3(pos.pos_x, pos.pos_y, pos.pos_z)
			
			%GlobalTwistPivot.rotation.y = pos.rot_y
			%GlobalTwistPivot/GlobalPitchPivot.rotation.x = pos.rot_x
			
			activate_cam("global")
			
			%WorldEnvironment.environment.tonemap_exposure = GAMMA
			
			pos.cooldown = COOLDOWN_VISION
			
		pos.cooldown -= delta
		
		if (pos.cooldown >= COOLDOWN_VISION - VISION_LENGTH):
			has_vision = true
			
		
		# Remet sombre si les 2 cooldowns sont terminés
		if (cooldown_flash < COOLDOWN_FLASH - FLASH_LENGTH):
			#%WorldEnvironment.environment.tonemap_exposure = 0.0
			pass
	
	if (!has_vision):
		activate_cam("local")
		%WorldEnvironment.environment.tonemap_exposure = 0.0
		
	
	# Décrémentation des cooldowns
	cooldown_flash -= delta
	cooldown_vision -= delta

# Gestion de tous les inputs qui ne sont pas gérés (meme si je sais pas trop ce qui n'est pas géré)
func _unhandled_input(event: InputEvent) -> void:
	# Gestion des mouvements de souris (pour la caméra)
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity
