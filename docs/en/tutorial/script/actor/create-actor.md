# Create Actor

## Function Description

Creates a new actor and displays it on the screen.

## Syntax Structure

```text
actor show [actor_name] [state] at [x] [y] scale [scale]
```

## Parameter Description

| Parameter | Required | Example | Description |
|------|------|------|------|
| actor_name | Yes | `bob` | Actor name |
| state | Yes | `happy` | Actor state (expression) |
| x | Yes | `400` | X coordinate |
| y | Yes | `300` | Y coordinate |
| scale | No | `0.8` | Actor scale (default: 1.0) |

## Examples

```text
# Create actor
actor show alice happy at 400 300 scale 0.8
```
