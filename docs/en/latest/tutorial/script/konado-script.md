---
title: KonadoScript
order: 1
---

# KonadoScript

KonadoScript is an authoring language tailored for visual novels. Its file extension is `.ks`.

You can think of it as a more powerful and more structured "novel script": developers can control story dialogue, character portraits, background switching, music and sound effects, story branches, and choices without writing complex code.

## Design Philosophy

The core design philosophy of KonadoScript is to separate **story content** from **program logic**:
- Writers focus on narrative content without needing programming knowledge
- Programmers focus on engine development without intervening in story creation
- Resource management (images and audio) uses identifiers and is decoupled from scripts
- Modular instruction set, easy to extend with new features
- Compatible with version control systems such as Git
- Text format is naturally cross-platform
- Resource references are platform-independent

## FAQ

### 1. Handling parse errors

Godot's Script Editor reports KonadoScript syntax and semantic problems as you type. Invalid content can still be saved to the `.ks` source file, but it does not replace the current runtime `KonadoShot`. Fix the errors and save again to let the resource loader compile it automatically; no manual reimport is required.

### 2. Script file encoding issues

Make sure the script file is encoded as UTF-8, otherwise garbled text may appear. Script files created by default use UTF-8 encoding.

### 3. Protecting scripts in exported builds

When a project is exported, Konado reads `Konado -> Script Encryption Key` from the current export preset and automatically encrypts the compiled `.ks` story data. If the key is empty or malformed, Konado generates a random 256-bit key for the build. Later exports reuse this key unless a developer changes it manually.

For patches or hot updates, the base build and update must use the same export preset and key. The key is stored in `.godot/konado_export_credentials.cfg`; back it up separately if it needs to be retained.

For local exports, the Godot terminal prints the complete build key for developer records and diagnostics. This protection prevents generic extraction tools from reading story text directly from a PCK; it is not dedicated DRM, and targeted analysis of exported resources, client code, or runtime memory may still recover the content.
