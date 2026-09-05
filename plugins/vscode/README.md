# Konado

Official Visual Studio Code language support for
[KonadoScript](https://godothub.com/oss/konado/en/latest/tutorial/script/konado-script.html),
the narrative scripting language used by Konado.

## Features

- Context-aware completion for commands, named parameters, actors, actor states,
  motions, backgrounds, audio, cameras, branches, variables, and script paths
- Real-time syntax and project-resource diagnostics
- Up to three ranked quick fixes for common authoring mistakes
- Hover documentation and command signatures
- Go to Definition for branches, scripts, actors, resources, and project symbols
- Find All References and safe rename for branches, variables, and signals
- Document and workspace symbols, semantic highlighting, folding, and symbol
  highlighting
- Deterministic document formatting that preserves dialogue, strings, and comments
- Clickable `res://...ks` links
- One-click switching between localized versions of the current script
- Workspace-wide KonadoScript validation

The extension indexes textual Godot `.tres` and `.tscn` resources without running
project scripts. Open a folder containing `project.godot` to enable project-aware
completion and navigation.

## Commands

- `Konado: Open Documentation`
- `Konado: Switch Script Language`
- `Konado: Reindex Godot Project`
- `Konado: Validate Workspace Scripts`

## Development

Requirements:

- Node.js 20 or newer
- pnpm 10
- Visual Studio Code 1.96 or newer

```bash
pnpm install
pnpm check
pnpm package:vsix
```

Press `F5` in Visual Studio Code to launch an Extension Development Host after
installing dependencies.

## Publishing

The Marketplace extension identifier is `GodotHub.Konado`:

- `publisher`: `GodotHub`
- `name`: `Konado`
- `displayName`: `Konado`

Run `pnpm package:vsix` to validate the extension and create
`dist/konado.vsix`, then upload the file manually in the Visual Studio
Marketplace publisher portal.

## License

MIT License.
