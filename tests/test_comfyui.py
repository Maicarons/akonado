"""Tests for akonado.providers.comfyui — WorkflowTemplate and ComfyUIClient."""

import json
import random
from pathlib import Path

import pytest

from akonado.providers.comfyui import WorkflowTemplate, ComfyUIClient


# ── Fixtures ─────────────────────────────────────────────────


@pytest.fixture
def ernie_workflow():
    """Load the real ernie image workflow for testing."""
    path = Path(__file__).resolve().parent.parent / "akonado" / "comfyui" / "image_ernie_image_turbo.json"
    if not path.exists():
        pytest.skip(f"Workflow not found: {path}")
    return WorkflowTemplate.load(path)


@pytest.fixture
def audio_workflow():
    """Load the real audio workflow for testing."""
    path = Path(__file__).resolve().parent.parent / "akonado" / "comfyui" / "audio_stable_audio_3.json"
    if not path.exists():
        pytest.skip(f"Workflow not found: {path}")
    return WorkflowTemplate.load(path)


@pytest.fixture
def simple_workflow():
    """A minimal synthetic workflow for unit testing."""
    return WorkflowTemplate({
        "1": {
            "class_type": "KSampler",
            "inputs": {
                "seed": 12345,
                "steps": 20,
                "cfg": 7.0,
                "model": ["2", 0],
                "positive": ["3", 0],
            },
        },
        "2": {
            "class_type": "PrimitiveStringMultiline",
            "inputs": {"value": "default prompt"},
            "_meta": {"title": "Prompt"},
        },
        "3": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": 512, "height": 512, "batch_size": 1},
        },
        "4": {
            "class_type": "SaveImage",
            "inputs": {"images": ["1", 0]},
        },
    })


# ── WorkflowTemplate.load ────────────────────────────────────


class TestWorkflowTemplateLoad:
    def test_load_valid_json(self, tmp_path):
        wf = {"1": {"class_type": "KSampler", "inputs": {"seed": 42}}}
        path = tmp_path / "test.json"
        path.write_text(json.dumps(wf), encoding="utf-8")
        tpl = WorkflowTemplate.load(path)
        assert tpl.workflow == wf

    def test_load_missing_file(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            WorkflowTemplate.load(tmp_path / "nonexistent.json")

    def test_load_invalid_json(self, tmp_path):
        path = tmp_path / "bad.json"
        path.write_text("{invalid json", encoding="utf-8")
        with pytest.raises(json.JSONDecodeError):
            WorkflowTemplate.load(path)


# ── WorkflowTemplate.inject — Seed Randomization ────────────


class TestInjectSeed:
    def test_random_seed_when_not_provided(self, simple_workflow):
        """KSampler seed should be randomized when no seed kwarg."""
        wf1 = simple_workflow.inject(prompt="test")
        wf2 = simple_workflow.inject(prompt="test")
        seed1 = wf1["1"]["inputs"]["seed"]
        seed2 = wf2["1"]["inputs"]["seed"]
        # Seeds should be different (with overwhelming probability)
        assert seed1 != seed2
        # Seeds should be in valid range
        assert 0 <= seed1 < 2**53
        assert 0 <= seed2 < 2**53

    def test_explicit_seed(self, simple_workflow):
        """KSampler seed should match when explicitly provided."""
        wf = simple_workflow.inject(prompt="test", seed=42)
        assert wf["1"]["inputs"]["seed"] == 42

    def test_seed_not_in_original(self, simple_workflow):
        """Original workflow should not be mutated."""
        original_seed = simple_workflow.workflow["1"]["inputs"]["seed"]
        simple_workflow.inject(prompt="test", seed=999)
        assert simple_workflow.workflow["1"]["inputs"]["seed"] == original_seed

    def test_ernie_workflow_seed_randomized(self, ernie_workflow):
        """Real ernie workflow should have randomized KSampler seed."""
        wf1 = ernie_workflow.inject(prompt="cat")
        wf2 = ernie_workflow.inject(prompt="cat")
        seed1 = wf1["88:70"]["inputs"]["seed"]
        seed2 = wf2["88:70"]["inputs"]["seed"]
        assert seed1 != seed2


# ── WorkflowTemplate.inject — Prompt Injection ───────────────


class TestInjectPrompt:
    def test_prompt_injected_to_primitive_string(self, simple_workflow):
        """PrimitiveStringMultiline 'Prompt' title should get prompt value."""
        wf = simple_workflow.inject(prompt="a cute cat")
        assert wf["2"]["inputs"]["value"] == "a cute cat"

    def test_ernie_prompt_injected(self, ernie_workflow):
        """Ernie workflow: PrimitiveStringMultiline should get prompt."""
        wf = ernie_workflow.inject(prompt="a dog in park", width=1024, height=1024)
        # Node 88:94 has title "String (Multiline - Prompt)"
        assert wf["88:94"]["inputs"]["value"] == "a dog in park"

    def test_ernie_template_preserved(self, ernie_workflow):
        """Ernie workflow: StringReplace template string should NOT be modified."""
        wf = ernie_workflow.inject(prompt="a dog", width=1024, height=1024)
        # Node 88:93 is StringReplace with template containing {prompt}
        template = wf["88:93"]["inputs"]["string"]
        assert "{prompt}" in template, "Template should still contain {prompt} placeholder"


# ── WorkflowTemplate.inject — Width/Height ───────────────────


class TestInjectDimensions:
    def test_empty_latent_image_updated(self, simple_workflow):
        """EmptyLatentImage width/height should be updated."""
        wf = simple_workflow.inject(prompt="test", width=1024, height=768)
        assert wf["3"]["inputs"]["width"] == 1024
        assert wf["3"]["inputs"]["height"] == 768

    def test_ernie_latent_image_updated(self, ernie_workflow):
        """Ernie workflow EmptyFlux2LatentImage should get width/height."""
        wf = ernie_workflow.inject(prompt="test", width=768, height=512)
        assert wf["88:71"]["inputs"]["width"] == 768
        assert wf["88:71"]["inputs"]["height"] == 512


# ── WorkflowTemplate.inject — LoadImage ──────────────────────


class TestInjectLoadImage:
    def test_load_image_updated(self):
        """LoadImage node's image input should be updated from kwargs."""
        tpl = WorkflowTemplate({
            "1": {
                "class_type": "LoadImage",
                "inputs": {"image": "default.png"},
            },
            "2": {
                "class_type": "SaveImage",
                "inputs": {"images": ["1", 0]},
            },
        })
        wf = tpl.inject(image="uploaded_character.png")
        assert wf["1"]["inputs"]["image"] == "uploaded_character.png"

    def test_load_image_not_overwritten_when_no_kwarg(self):
        """LoadImage node should keep default when no image kwarg."""
        tpl = WorkflowTemplate({
            "1": {
                "class_type": "LoadImage",
                "inputs": {"image": "default.png"},
            },
        })
        wf = tpl.inject(prompt="test")
        assert wf["1"]["inputs"]["image"] == "default.png"

    def test_real_remove_bg_workflow(self):
        """Real remove_background workflow should get image injected."""
        path = Path(__file__).resolve().parent.parent / "akonado" / "comfyui" / "utility_birefnet_remove_background.json"
        if not path.exists():
            pytest.skip(f"Workflow not found: {path}")
        tpl = WorkflowTemplate.load(path)
        wf = tpl.inject(image="my_character.png")
        assert wf["17"]["inputs"]["image"] == "my_character.png"


# ── WorkflowTemplate.inject — Audio Duration ─────────────────


class TestInjectAudio:
    def test_audio_duration_injected(self, tmp_path):
        """PrimitiveFloat with 'duration' title should get duration value."""
        tpl = WorkflowTemplate({
            "1": {
                "class_type": "KSampler",
                "inputs": {"seed": 42, "steps": 20},
            },
            "2": {
                "class_type": "PrimitiveFloat",
                "inputs": {"value": 30.0},
                "_meta": {"title": "Audio Duration"},
            },
        })
        wf = tpl.inject(prompt="test", duration=60.0)
        assert wf["2"]["inputs"]["value"] == 60.0


# ── WorkflowTemplate.inject — Isolation ──────────────────────


class TestInjectIsolation:
    def test_does_not_mutate_original(self, simple_workflow):
        """inject() should return a deep copy, not modify the original."""
        original = json.dumps(simple_workflow.workflow)
        simple_workflow.inject(prompt="mutated", seed=999, width=2048, height=2048)
        assert json.dumps(simple_workflow.workflow) == original


# ── WorkflowTemplate.find_output_images ──────────────────────


class TestFindOutputImages:
    def test_finds_images(self):
        tpl = WorkflowTemplate({})
        result = {
            "outputs": {
                "1": {"images": [{"filename": "img1.png", "subfolder": ""}]},
                "2": {"images": [{"filename": "img2.png", "subfolder": "sub"}]},
            }
        }
        images = tpl.find_output_images(result)
        assert len(images) == 2
        assert images[0]["filename"] == "img1.png"
        assert images[1]["filename"] == "img2.png"

    def test_no_images(self):
        tpl = WorkflowTemplate({})
        result = {"outputs": {"1": {"text": "no images here"}}}
        assert tpl.find_output_images(result) == []

    def test_empty_outputs(self):
        tpl = WorkflowTemplate({})
        assert tpl.find_output_images({}) == []


# ── WorkflowTemplate.find_output_audio ───────────────────────


class TestFindOutputAudio:
    def test_finds_audio(self):
        tpl = WorkflowTemplate({})
        result = {
            "outputs": {
                "1": {"audio": [{"filename": "bgm.mp3", "subfolder": ""}]},
            }
        }
        audio = tpl.find_output_audio(result)
        assert len(audio) == 1
        assert audio[0]["filename"] == "bgm.mp3"

    def test_no_audio(self):
        tpl = WorkflowTemplate({})
        assert tpl.find_output_audio({"outputs": {}}) == []


# ── ComfyUIClient — Workflow Discovery ──────────────────────


class TestComfyUIClientDiscovery:
    def test_discovers_real_workflows(self):
        """Should discover workflows from akonado/comfyui/ directory."""
        client = ComfyUIClient()
        workflows = client.list_workflows()
        assert "image:ernie_image_turbo" in workflows
        assert "audio:stable_audio_3" in workflows
        assert "utility:remove_bg" in workflows

    def test_get_workflow(self):
        client = ComfyUIClient()
        tpl = client.get_workflow("image:ernie_image_turbo")
        assert tpl is not None
        assert isinstance(tpl, WorkflowTemplate)

    def test_get_nonexistent_workflow(self):
        client = ComfyUIClient()
        assert client.get_workflow("image:nonexistent") is None

    def test_find_first_image(self):
        client = ComfyUIClient()
        tpl = client._find_first("image:")
        assert tpl is not None

    def test_find_first_nonexistent(self):
        client = ComfyUIClient()
        assert client._find_first("video:") is None

    def test_custom_comfyui_dir(self, tmp_path):
        """Should discover workflows from custom directory."""
        # Create a minimal workflow
        wf = {"1": {"class_type": "SaveImage", "inputs": {"images": ["2", 0]}}}
        (tmp_path / "image_test.json").write_text(json.dumps(wf), encoding="utf-8")

        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert "image:test" in client.list_workflows()

    def test_empty_directory(self, tmp_path):
        """Should handle empty comfyui directory gracefully."""
        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert client.list_workflows() == []


# ── ComfyUIClient — Workflow Type Detection ─────────────────


class TestWorkflowTypeDetection:
    def test_detects_image_type(self):
        tpl = WorkflowTemplate({
            "1": {"class_type": "SaveImage", "inputs": {}},
        })
        assert ComfyUIClient._detect_workflow_type(tpl) == "image"

    def test_detects_audio_type(self):
        tpl = WorkflowTemplate({
            "1": {"class_type": "SaveAudioMP3", "inputs": {}},
        })
        assert ComfyUIClient._detect_workflow_type(tpl) == "audio"

    def test_detects_preview_image(self):
        tpl = WorkflowTemplate({
            "1": {"class_type": "PreviewImage", "inputs": {}},
        })
        assert ComfyUIClient._detect_workflow_type(tpl) == "image"

    def test_no_output_nodes(self):
        tpl = WorkflowTemplate({
            "1": {"class_type": "KSampler", "inputs": {}},
        })
        assert ComfyUIClient._detect_workflow_type(tpl) is None

    def test_audio_takes_precedence(self):
        """If workflow has both image and audio outputs, audio wins."""
        tpl = WorkflowTemplate({
            "1": {"class_type": "SaveImage", "inputs": {}},
            "2": {"class_type": "SaveAudio", "inputs": {}},
        })
        assert ComfyUIClient._detect_workflow_type(tpl) == "audio"


# ── ComfyUIClient — Prefix Classification ───────────────────


class TestPrefixClassification:
    def test_image_prefix(self, tmp_path):
        wf = {"1": {"class_type": "SaveImage", "inputs": {}}}
        (tmp_path / "image_foo.json").write_text(json.dumps(wf), encoding="utf-8")
        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert "image:foo" in client.list_workflows()

    def test_audio_prefix(self, tmp_path):
        wf = {"1": {"class_type": "SaveAudioMP3", "inputs": {}}}
        (tmp_path / "audio_bar.json").write_text(json.dumps(wf), encoding="utf-8")
        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert "audio:bar" in client.list_workflows()

    def test_remove_background_suffix(self, tmp_path):
        wf = {"1": {"class_type": "SaveImage", "inputs": {}}}
        (tmp_path / "birefnet_remove_background.json").write_text(json.dumps(wf), encoding="utf-8")
        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert "utility:remove_bg" in client.list_workflows()

    def test_unknown_prefix_fallback(self, tmp_path):
        wf = {"1": {"class_type": "SaveImage", "inputs": {}}}
        (tmp_path / "something_else.json").write_text(json.dumps(wf), encoding="utf-8")
        client = ComfyUIClient(comfyui_dir=tmp_path)
        assert "image:something_else" in client.list_workflows()
