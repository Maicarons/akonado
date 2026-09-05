---
title: Custom Dialogue Box
order: 4
---

# Custom Dialogue Interface

## Introduction

To customize the dialogue interface, first copy the selected template scene into your project's own directory, such as `res://ui/dialogue/`. Edit that copy or assign it a custom Godot theme.

Do not edit files under `res://addons/konado/` directly; plugin upgrades replace the plugin directory. A project-owned copy remains safe when Konado is upgraded.

## Edit Template Files

`res://addons/konado/templates/` contains the built-in dialogue templates. Copy the required `.tscn` into your project, instantiate the copy in your dialogue scene, and assign its `KonadoDialogueBox` node to the `dialogue_box` property of `KonadoDialogueManager`.

In general, do not modify scripts on nodes. Prefer changing node properties to achieve customization.

## Visibility API

`KonadoDialogueBox` separates temporary hiding from dismissing content:

```gdscript
dialogue_box.hide_dialogue_box()
dialogue_box.hide_dialogue_box_with_duration(0.5)

dialogue_box.dismiss_dialogue_box()
dialogue_box.dismiss_dialogue_box_with_duration(0.5)
```

The `hide_dialogue_box*()` methods preserve the current speaker and text for later restoration. The `dismiss_dialogue_box*()` methods clear that content after the hide animation completes and are appropriate when the current dialogue content has ended. The KonadoScript `hidetextbox` command uses the latter behavior.

## UI Layer Contract

The built-in UI uses the following `CanvasLayer.layer` values so full-screen interfaces do not obscure one another based on scene-tree order:

| Layer | Purpose |
|-------|---------|
| `1` | Stage, backgrounds, and acting content |
| `10` | Dialogue box, choices, and dialogue toolbar |
| `50` | Save interface |
| `100` | Modal panels such as settings and achievements |
| `110` | Short-lived notifications such as achievement unlocks |
| `120` | Runtime errors that must remain above all built-in UI |

Place custom UI in the range appropriate to its purpose. Avoid layer `120` or higher unless it must cover system error messages. Achievement layers can also be adjusted through `KonadoAchievements.panel_layer` and `popup_layer`.

## Customize Voice Progress

When a regular dialogue line has a voice tag and its audio is playing, the dialogue box displays playback progress. It hides the indicator when no voice is assigned, the resource cannot be resolved, or playback ends. Disable `show_voice_progress` on the `KonadoDialogueBox` node if the project does not need it.

The built-in component source is `res://addons/konado/templates/default/voice_progress_display.tscn`. Copy it into the project before changing its colors, corner radii, dimensions, or node structure, then reference that copy from the customized dialogue box. A complete replacement should preserve this interface:

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
