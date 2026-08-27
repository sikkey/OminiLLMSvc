# OminiLLMSvc

Language: [English](README.md) | [中文](README.zh-CN.md)

## Intro

OminiLLMSvc provides a lightweight proxy service that adapts any application to work with Large Language Model (LLM) APIs. It forwards requests to your chosen LLM provider (e.g. OpenAI) and handles configuration management automatically.

## Build & Install

Requirements: [Node.js](https://nodejs.org/) v16 or later.

```bash
# Clone the repository
git clone https://github.com/sikkey/OminiLLMSvc.git
cd OminiLLMSvc

# No additional dependencies required — uses Node.js built-in modules only
```

Run the platform-specific installer to initialize the app config from the template files without overwriting any existing custom settings:

```bash
# Windows
install.bat

# macOS / Linux
bash install.sh
```

The installer copies any files from `template/config/` into `apps/config/` only when the target file does not already exist, so your custom configuration is preserved.

## Configuration

The application uses a JSON config file located at `apps/config/llm-coder-proxy.config.json`.

This file is **not tracked by git** (`*.config.json` is in `.gitignore`). On first run, the application will automatically create the `apps/config` directory and copy the template from `template/config/llm-coder-proxy.config.json` to `apps/config/llm-coder-proxy.config.json`, then exit, prompting you to fill in your settings.

```bash
cp -r ./template/config/ ./apps/config/
```

Edit `apps/config/llm-coder-proxy.config.json` and set at minimum:

```json
{
  "server": {
    "port": 7070,
    "host": "127.0.0.1"
  },
  "llm": {
    "provider": "openai",
    "apiKey": "<your-api-key>",
    "model": "gpt-4",
    "baseUrl": "https://api.openai.com/v1"
  }
}
```

## Run

```bash
node apps/llm-coder-proxy.js
```

The proxy will start and listen on the host and port specified in the config (default: `http://127.0.0.1:7070`).

Health check endpoint: `GET /health` — returns `{ "status": "ok" }`.

## LLM Compatibility

OminiLLMSvc is designed to work with OpenAI-compatible endpoints and common local model runtimes, including `llama.cpp`-style plugins and general-purpose models such as `gemma4` that are not specialized code-generation models.

For compatibility, the proxy supports both standard chat access and a lightweight infill route:

- `POST /v1/chat/completions` for chat-style use
- `POST /infill` or `POST /v1/infill` for code completion / infill scenarios

When a backend model does not expose a native infill API, OminiLLMSvc translates the request into a chat-completion prompt that asks the model to complete only the missing code between a prefix and suffix. This enables general models like `gemma4` to behave like a code completion assistant without requiring a dedicated coder model.

This makes it useful for local runtimes and editor integrations that expect an OpenAI-compatible API surface but run non-coder general-purpose models.

## FAQ

**Q: The app exits immediately on first run.**  
A: This is expected. On first run the config file is created from the template. Edit `apps/llm-coder-proxy.config.json` with your API key and other settings, then run the app again.

**Q: Where is my config file stored?**  
A: `apps/config/llm-coder-proxy.config.json`. This file is git-ignored so your API keys are never committed.

**Q: How do I change the LLM provider or model?**  
A: Edit the `llm` section of your config file and update `provider`, `baseUrl`, and `model` as needed.
