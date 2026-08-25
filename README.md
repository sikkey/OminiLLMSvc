# OminiLLMSvc

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

## Configuration

The application uses a JSON config file located at `apps/llm-coder-proxy.config.json`.

This file is **not tracked by git** (`*.config.json` is in `.gitignore`). On first run, the application will automatically copy the template from `template/config/llm-coder-proxy.config.json` to `apps/llm-coder-proxy.config.json` and then exit, prompting you to fill in your settings.

Edit `apps/llm-coder-proxy.config.json` and set at minimum:

```json
{
  "server": {
    "port": 3000,
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

The proxy will start and listen on the host and port specified in the config (default: `http://127.0.0.1:3000`).

Health check endpoint: `GET /health` — returns `{ "status": "ok" }`.

## F.A.Q

**Q: The app exits immediately on first run.**  
A: This is expected. On first run the config file is created from the template. Edit `apps/llm-coder-proxy.config.json` with your API key and other settings, then run the app again.

**Q: Where is my config file stored?**  
A: `apps/llm-coder-proxy.config.json`. This file is git-ignored so your API keys are never committed.

**Q: How do I change the LLM provider or model?**  
A: Edit the `llm` section of your config file and update `provider`, `baseUrl`, and `model` as needed.
