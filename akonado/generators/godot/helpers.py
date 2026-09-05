"""Shared helpers for .tres file generation."""

from __future__ import annotations


def tres_header(script_class: str, load_steps: int) -> str:
    """Generate .tres header."""
    return (
        f'[gd_resource type="Resource" script_class="{script_class}"'
        f" load_steps={load_steps} format=3]\n"
    )


def ext_resource_script(path: str, res_id: str) -> str:
    return f'[ext_resource type="Script" path="{path}" id="{res_id}"]\n'


def ext_resource_texture(path: str, res_id: str) -> str:
    return f'[ext_resource type="Texture2D" path="{path}" id="{res_id}"]\n'


def ext_resource_audio(path: str, res_id: str) -> str:
    return f'[ext_resource type="AudioStream" path="{path}" id="{res_id}"]\n'


def ext_resource_scene(path: str, res_id: str) -> str:
    return f'[ext_resource type="PackedScene" path="{path}" id="{res_id}"]\n'
