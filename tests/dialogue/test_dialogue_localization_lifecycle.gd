extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_hot_locale_overlay_preserves_instruction_identity()
	await _test_incompatible_locale_is_rejected_transactionally()
	await _test_locale_switch_does_not_duplicate_callbacks()
	if _failures == 0:
		print("PASS: Program localization lifecycle tests")
	quit(_failures)


func _test_hot_locale_overlay_preserves_instruction_identity() -> void:
	var manager := await _create_manager()
	var source := _compile_shot(
		'"Kona" "Source" [id=line]\nend [id=done]', "res://tests/dialogue/story.ks"
	)
	var localized_program := _compile_shot(
		'"Kona" "本地化" [id=line]\nend [id=done]',
		"res://tests/dialogue/story.zh_Hans.ks",
	)
	var overlay_result := KonadoLocaleOverlay.build(
		source.program, localized_program.program, "zh_Hans"
	)
	_expect(bool(overlay_result.get("ok", false)), "fixture overlay is structurally compatible")
	var localized := source.duplicate() as KonadoShot
	localized.source_path = "res://tests/dialogue/story.zh_Hans.ks"
	localized.install_locale_overlay(overlay_result.get("overlay"))
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized
	root.add_child(service)
	manager._story_localization = service
	_expect(manager._install_shot(source), "source Program installs")
	manager.start_dialogue_shot = source
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:line", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(manager.reload_localized_script("zh_Hans"), "compatible locale hot switch succeeds")
	_expect_equal(
		manager._current_instruction().stable_key(), "ks:id:line", "identity is preserved"
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "本地化", "visible text is refreshed")
	await _free_node(manager)
	await _free_node(service)


func _test_incompatible_locale_is_rejected_transactionally() -> void:
	var source := _compile_shot(
		'"Kona" "Source" [id=line]\nend [id=done]', "res://tests/dialogue/story.ks"
	)
	var incompatible := _compile_shot(
		'"Kona" "Other" [id=line]\nsignal changed\nend [id=done]',
		"res://tests/dialogue/story.zh_Hans.ks",
	)
	var result := KonadoLocaleOverlay.build(source.program, incompatible.program, "zh_Hans")
	_expect(not bool(result.get("ok", false)), "control-flow drift is rejected")
	_expect(source.locale_overlay == null, "failed overlay validation is non-mutating")


func _test_locale_switch_does_not_duplicate_callbacks() -> void:
	var manager := await _create_manager()
	var source := _compile_shot(
		'"Kona" "Source" [id=line]\nend [id=done]', "res://tests/dialogue/story.ks"
	)
	var translated := _compile_shot(
		'"Kona" "Translated" [id=line]\nend [id=done]',
		"res://tests/dialogue/story.en.ks",
	)
	var result := KonadoLocaleOverlay.build(source.program, translated.program, "en")
	var localized := source.duplicate() as KonadoShot
	localized.install_locale_overlay(result.get("overlay"))
	var service := FakeLocalizedScriptService.new()
	service.localized_shot = localized
	root.add_child(service)
	manager._story_localization = service
	_expect(manager._install_shot(source), "source Program installs")
	manager.start_dialogue_shot = source
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	var before := manager.dialogue_box.typing_completed.get_connections().size()
	manager.reload_localized_script("en")
	manager.reload_localized_script("en")
	var after := manager.dialogue_box.typing_completed.get_connections().size()
	_expect_equal(after, before, "locale refresh does not reconnect the active instruction")
	await _free_node(manager)
	await _free_node(service)
