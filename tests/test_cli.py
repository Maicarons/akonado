"""Tests for akonado.cli — CLI argument parsing and helper functions."""

import json
from pathlib import Path

import pytest

from akonado.cli import _strip_markdown_code_blocks


# ── _strip_markdown_code_blocks ──────────────────────────────


class TestStripMarkdownCodeBlocks:
    def test_strips_json_block(self):
        input_text = '```json\n{"key": "value"}\n```'
        assert _strip_markdown_code_blocks(input_text) == '{"key": "value"}'

    def test_strips_plain_block(self):
        input_text = '```\nsome text\n```'
        assert _strip_markdown_code_blocks(input_text) == 'some text'

    def test_no_block(self):
        input_text = '{"key": "value"}'
        assert _strip_markdown_code_blocks(input_text) == '{"key": "value"}'

    def test_strips_whitespace(self):
        input_text = '  \n```json\n{"a": 1}\n```  \n'
        assert _strip_markdown_code_blocks(input_text) == '{"a": 1}'

    def test_only_opening_fence(self):
        input_text = '```json\n{"a": 1}'
        assert _strip_markdown_code_blocks(input_text) == '{"a": 1}'

    def test_only_closing_fence(self):
        input_text = '{"a": 1}\n```'
        assert _strip_markdown_code_blocks(input_text) == '{"a": 1}'

    def test_empty_string(self):
        assert _strip_markdown_code_blocks('') == ''

    def test_multiline_content(self):
        input_text = '```json\n{\n  "chapters": [1, 2, 3],\n  "title": "test"\n}\n```'
        result = _strip_markdown_code_blocks(input_text)
        parsed = json.loads(result)
        assert parsed["chapters"] == [1, 2, 3]
        assert parsed["title"] == "test"

    def test_nested_json(self):
        data = {"characters": [{"id": "hero", "name": "Hero"}]}
        input_text = f"```json\n{json.dumps(data, ensure_ascii=False)}\n```"
        result = _strip_markdown_code_blocks(input_text)
        parsed = json.loads(result)
        assert parsed["characters"][0]["id"] == "hero"
