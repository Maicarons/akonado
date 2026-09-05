---
title: Installation
order: 1
---

# Installation

## Basic Dependencies

1. Install the Konado plugin (required)
2. Godot .NET 4.7.1 or later
3. Open the project with the Godot .NET editor. The regular Godot editor cannot compile or load C# addon scripts.

## Installation Steps

1. Extract the konado_dotnet plugin into the `addons` directory of your Godot project
2. Make sure the main `addons/konado` plugin is also present
3. In the Godot editor, open `Project -> Project Settings -> Plugins` and enable `Konado` first
4. Build the C# project and make sure MSBuild reports no errors
5. Enable the `Konado.NET` plugin
6. Reopen the project so autoloads and C# scripts are refreshed

## First Enable Errors

When enabling Konado.NET for the first time before the C# project has been built, you may see:

```text
Unable to load addon script from path: 'res://addons/konado_dotnet/editor/KonadoDotNetPlugin.cs'.
```

This is usually not a main Konado plugin issue. Build the project with the Godot .NET editor, reopen the project, then enable the plugin again.

## Enable Order

Konado.NET depends on the main Konado plugin. Recommended order:

1. Enable `Konado`
2. Build the C# project
3. Enable `Konado.NET`

If Konado.NET is enabled first, it checks the main plugin status and will not register the API autoload when the main plugin is disabled.

## Scene Requirement

`DialogueManagerApi` requires a `KonadoDialogueManager` node that satisfies the complete
public API contract. Konado.NET binds it automatically when it enters the scene tree;
the node name does not matter.

If a scene contains multiple dialogue managers, bind one manually:

```csharp
using Godot;

var manager = GetNode<Node>("UI/KonadoDialogueManager");
Konado.Runtime.Api.KonadoApi.DialogueManagerApi?.BindDialogueManager(manager);
```
