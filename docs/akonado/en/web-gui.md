# Web GUI

Akonado includes a Flask-based Web GUI providing a browser-based visual management interface.

## Starting

```bash
python -m akonado web
```

Open http://127.0.0.1:5000 in your browser.

### Configuration

In `.env`:

```env
WEB_HOST=127.0.0.1
WEB_PORT=5000
WEB_DEBUG=false
```

Or via CLI arguments:

```bash
python -m akonado web --host 0.0.0.0 --port 8080 --debug
```

## Features

### Dashboard

- Asset generation statistics: character count, background count, BGM count, SFX count, voice count, script count
- Provider status indicators (ComfyUI / LLM / TTS)
- Quick action entry points

### Manifests

- View all JSON manifests
- Built-in JSON editor with formatting support
- Save changes directly to disk
- JSON syntax error highlighting

### Skills

- Browse all available skills
- View/edit skill templates (system_prompt, user_prompt_template)
- Run skills with custom input
- View LLM output results

### Configuration Editor

- Edit `.env` configuration file online
- Changes take effect immediately (on next generation)

## API Endpoints

The Web GUI provides REST API endpoints for external tools:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/providers` | GET | Check all provider statuses |
| `/api/stats` | GET | Get asset statistics |
| `/api/generate` | POST | Trigger asset generation |
| `/api/skill/run` | POST | Run an LLM skill |

### Generate API

```bash
# Generate all assets
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{"type": "all", "engine": "mimo", "force": false}'

# Generate specific type
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{"type": "characters"}'
```

### Skill Run API

```bash
curl -X POST http://localhost:5000/api/skill/run \
  -H "Content-Type: application/json" \
  -d '{
    "name": "generate_script",
    "input": "A story about a cat",
    "variables": {"num_chapters": "3"},
    "temperature": 0.7
  }'
```
