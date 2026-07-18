# Local AI Tools

This repository contains a small CLI-first local AI setup for Windows.

## What it includes

- `setup-local-ai-cli.ps1` — installs the local stack
- `aider-local.ps1` — starts Aider against a local Ollama model
- `aider-local.cmd` — Windows command wrapper for the PowerShell launcher
- `chat-local.ps1` — launches a local chat workflow with Ollama
- `chat-local.cmd` — Windows command wrapper for the chat launcher
- `config.json` — default model and behavior settings

## Quick start

Run the setup script from PowerShell:

```powershell
setup-local-ai-cli
```

Then launch Aider from a repository folder:

```powershell
aider-local
```

Or launch a simple chat session:

```powershell
chat-local
```

## Defaults

The default models are:

- Coding: `qwen2.5-coder:7b`
- General chat: `qwen2.5:7b`
- Embedding: `nomic-embed-text`
- Optional reasoning: `qwen2.5:14b`

## Notes

- Ollama must be running locally at `http://127.0.0.1:11434`
- Aider expects the local Ollama endpoint to be available
- The scripts are meant to be a practical starting point for local coding and chat workflows
