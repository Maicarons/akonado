---
title: Change Actor State
order: 4
---

# Change Actor State

## Description
Switch the state of the specified actor. Characters that can safely provide state frames use a true visual blend; other characters automatically fall back to fading out, applying the state, and fading in. Story execution resumes after the transition finishes.

## Syntax

```text
actor change <character name> <new state>
```

## Parameters

| Parameter | Required | Example | Description |
|------|------|------|------|
| Character | Yes | kona | Name of the actor whose state should be changed |
| New state | Yes | happy | New state to switch to |

## Example

```text
actor change kona happy
```

## State transition

`actor change` selects the transition path automatically:

1. If the character scene provides current and target state frames, blend them with a premultiplied-alpha shader.
2. Otherwise, safely fade the current actor out, apply the state, and fade it in.
3. Continue with the next story command after the transition finishes.

Configure the transition in the Inspector for the `KonadoStageController` node:

| Property | Default | Description |
|------|------|------|
| `actor_state_transition_enabled` | `true` | Enables the fade transition for actor state changes |
| `actor_state_transition_duration` | `0.3` | Total transition duration in seconds; the safe fallback splits it equally between fade-out and fade-in |

Disable `actor_state_transition_enabled` or set `actor_state_transition_duration` to `0` to switch states immediately.

Transitions never duplicate the character scene. The bundled AnimatedSprite2D example uses pure texture frames for a true blend. A custom state frame must represent the complete character image, not just one visible component. Video, Spine, Live2D, and custom scenes without complete, safe state frames automatically use the fallback, so scripts, audio, and dynamic media are never started twice. If the target actor is missing or its scene cannot apply the state, Konado completes the command and continues the story instead of waiting indefinitely.
