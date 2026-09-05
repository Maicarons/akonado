"""List ComfyUI workflows command."""

from __future__ import annotations

import argparse


def cmd_workflows(_args: argparse.Namespace) -> None:
    """List discovered ComfyUI workflows."""
    from ..providers import ComfyUIClient

    client = ComfyUIClient()
    workflows = client.list_workflows()

    if not workflows:
        print("No ComfyUI workflows found in comfyui/")
        print("Add workflow JSON files with prefixes: image_*, audio_*, utility_*")
        return

    print(f"ComfyUI workflows ({len(workflows)}):\n")
    for wf_name in workflows:
        tpl = client.get_workflow(wf_name)
        node_count = len(tpl.workflow) if tpl else 0
        print(f"  {wf_name}  ({node_count} nodes)")

    print(f"\nComfyUI URL: {client._base_url}")
    print(f"Available: {'Yes' if client.available() else 'No'}")
