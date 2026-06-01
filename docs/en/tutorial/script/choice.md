---
title: Choice
order: 7
---

# Choice Jump

## Overview

This feature is used together with **branches**. It configures jump logic in interactive choices, so clicking a choice can jump directly to a specific branch node. Each `choice` statement creates one option. Multiple adjacent `choice` lines are merged into one option group and displayed together during interaction.

## Syntax

```text
choice "Choice text" -> branch_name
```

| Parameter | Required | Example | Description |
|-----------|----------|---------|-------------|
| Choice text | Yes | `"Choose coffee"` | The option text shown during interaction |
| Branch name | Yes | `coffee_choice` | The unique target branch identifier |

## Examples

Write each option on its own line:

```text
choice "Green tea" -> green_tea
choice "Black tea" -> black_tea
```

You can also write multiple options on one line:

```text
choice "Green tea" -> green_tea "Black tea" -> black_tea
```

## Notes

1. The branch name must exactly match a branch identifier defined in the project. It is case-sensitive and cannot contain spaces or special symbols.
2. Choice text must be wrapped in English double quotes and supports normal text characters.
3. `->` is the separator between the choice and the branch name and cannot be omitted.
