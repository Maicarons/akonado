extends SceneTree

const VALID_CHARACTER_SCENE := preload("res://sample/demo/sample_character.tscn")
const READY_DEPENDENT_CHARACTER_SCENE := preload(
	"res://tests/character/fixtures/ready_dependent_character.tscn"
)
const LAYOUT_DEPENDENT_CHARACTER_SCENE := preload(
	"res://tests/character/fixtures/layout_dependent_character.tscn"
)

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor_scene := (
		load("res://addons/konado/templates/default/character/character_template.tscn")
		as PackedScene
	)
	var valid_actor := actor_scene.instantiate() as KonadoActor
	get_root().add_child(valid_actor)
	await process_frame
	var original_motion_layer := valid_actor.motion_layer
	_expect(
		not valid_actor.set_motion_layer_scene(VALID_CHARACTER_SCENE),
		"invalid custom motion layers report failure"
	)
	_expect_equal(
		valid_actor.motion_layer,
		original_motion_layer,
		"invalid custom motion layers preserve the working default layer"
	)
	_expect(
		original_motion_layer != null and original_motion_layer.get_parent() == valid_actor.slot,
		"the preserved default motion layer remains mounted"
	)
	_expect(
		valid_actor.set_character_scene(VALID_CHARACTER_SCENE, "介绍正常"),
		"valid initial states report success after entering the scene tree"
	)
	var character_scene := valid_actor._status_node as KonadoCharacterSceneBase
	_expect(character_scene != null, "valid character scenes are instantiated")
	if character_scene:
		_expect_equal(
			character_scene.current_status_name,
			"介绍正常",
			"successful initial states become the committed scene status"
		)

	var invalid_actor := actor_scene.instantiate() as KonadoActor
	get_root().add_child(invalid_actor)
	await process_frame
	_expect(
		not invalid_actor.set_character_scene(VALID_CHARACTER_SCENE, "missing"),
		"missing initial states report failure after entering the scene tree"
	)
	_expect_equal(
		invalid_actor._status_node,
		null,
		"failed initial states discard the uncommitted candidate scene"
	)

	var committed_scene := valid_actor._status_node
	_expect(
		not valid_actor.set_character_scene(VALID_CHARACTER_SCENE, "missing"),
		"invalid replacement states report failure"
	)
	_expect_equal(
		valid_actor._status_node,
		committed_scene,
		"invalid replacement states preserve the committed character scene"
	)
	_expect(
		committed_scene != null and committed_scene.get_parent() != null,
		"the preserved character scene remains mounted"
	)

	var ready_actor := actor_scene.instantiate() as KonadoActor
	get_root().add_child(ready_actor)
	await process_frame
	_expect(
		ready_actor.set_character_scene(READY_DEPENDENT_CHARACTER_SCENE, "ready"),
		"initial state validation runs after the character scene is ready"
	)

	var layout_actor := actor_scene.instantiate() as KonadoActor
	layout_actor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layout_actor.size = Vector2(640.0, 360.0)
	get_root().add_child(layout_actor)
	await process_frame
	_expect(
		layout_actor.set_character_scene(LAYOUT_DEPENDENT_CHARACTER_SCENE, "layout_ready"),
		"layout-dependent initial states are accepted"
	)
	var layout_character := layout_actor._status_node
	var initial_layout_size: Vector2 = layout_character.get("size_during_initial_status")
	_expect(
		initial_layout_size.is_equal_approx(layout_actor.slot.size),
		"candidate controls are laid out before their initial status hook runs"
	)

	valid_actor.queue_free()
	invalid_actor.queue_free()
	ready_actor.queue_free()
	layout_actor.queue_free()
	await process_frame
	character_scene = null
	valid_actor = null
	invalid_actor = null
	ready_actor = null
	layout_actor = null
	actor_scene = null
	if _failures == 0:
		print("PASS: actor initial state tests")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
