---
title: Scene-based assets
order: 8
---

# Scene-based assets

Character and background entries now reference `PackedScene` resources. A scene may contain textures, video, Spine, Live2D, shaders, or custom nodes.

Character scenes should inherit `KonadoCharacterSceneBase` and override `_apply_status(resolved_status_name, original_status_name)`; scenes that can validate state names should also override `_has_status`. `_has_status` must be side-effect-free and idempotent because a delayed transition may query it when accepting the request and again at final commit. Scenes that safely expose pure textures may implement both `_get_current_status_transition_frame` and `_get_status_transition_frame` for a true premultiplied-alpha blend. Live2D, Spine, video, and custom scenes that cannot provide side-effect-free frames automatically use the safe fade-out/apply/fade-in path. Neither path duplicates the character scene. See [Change Actor State](../script/actor/actor-change-state.md) for configuration. Optional stage motion belongs in a `KonadoActorMotionLayer` scene whose `AnimationPlayer` animation names match KS motion names.

Each transition-frame call must return a newly created, independent frame; do not reuse and mutate the same frame for both endpoints.

Background scenes should inherit `KonadoBackgroundSceneBase`. Assign the scene to `background_scene`; add uniquely named `KonadoCameraMarker` nodes when camera commands are needed. These nodes only store target positions and zoom values; the dialogue template's camera renders the scene. Do not replace a custom rendering camera with `KonadoCameraMarker`. Built-in transitions are handled by `KonadoBackgroundTransitionLayer`. Transitions capture the complete scene through `SubViewport` by default. Select `DIRECT_TEXTURE` only when the rendered background is exactly equivalent to one unmodified source texture; backgrounds with layout, transforms, cameras, animation, materials, tinting, or multiple drawables must keep `VIEWPORT_CAPTURE`.

Configure the corresponding `character_scene` or `background_scene` in the resource list. Keep node paths stable and make scene roots fill their parent when they are UI-based.
