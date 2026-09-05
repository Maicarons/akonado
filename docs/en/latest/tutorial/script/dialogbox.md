---
title: Show or hide the dialogue box
order: 5
---

# Show or hide the dialogue box

These commands control dialogue-box visibility and wait for the fade animation to finish before advancing.

## Syntax

```text
showtextbox [duration]
hidetextbox [duration]
```

`duration` is optional, is measured in seconds, and cannot be negative. Omit it or use `0.0` for an immediate visibility change.

After hiding completes, `hidetextbox` clears the current speaker and dialogue text so the previous line cannot briefly reappear the next time the dialogue box is shown.

## Examples

```text
# Fade the dialogue box in over one second
showtextbox 1.0

# Fade the dialogue box out over half a second
hidetextbox 0.5

# Change visibility immediately
showtextbox 0.0
hidetextbox 0.0
```
