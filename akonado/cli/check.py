"""Check provider availability."""

from __future__ import annotations

import argparse


def cmd_check(_args: argparse.Namespace) -> None:
    """Check provider availability."""
    from ..providers import ComfyUIClient, MiMoTTS, OpenAICompatibleLLM, QwenTTS

    comfyui = ComfyUIClient()
    providers = [
        ("ComfyUI (Image/Audio)", comfyui),
        ("LLM (OpenAI-compatible)", OpenAICompatibleLLM()),
        ("MiMo TTS", MiMoTTS()),
        ("Qwen TTS", QwenTTS()),
    ]

    all_ok = True
    for name, provider in providers:
        ok = provider.available()
        status = "OK" if ok else "NOT AVAILABLE"
        print(f"  {name}: {status}")
        if not ok:
            all_ok = False

    workflows = comfyui.list_workflows()
    if workflows:
        print(f"\nComfyUI workflows ({len(workflows)}):")
        for wf in workflows:
            print(f"  - {wf}")
    else:
        print("\nNo ComfyUI workflows found in comfyui/")

    if all_ok:
        print("\nAll providers are available.")
    else:
        print("\nSome providers are not available. Check your .env configuration.")
