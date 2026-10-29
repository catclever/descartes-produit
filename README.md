# Descartes Produit

[![Ruby](https://img.shields.io/badge/Language-Ruby-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-0.2.0-green.svg)](lib/descartes/hub/version.rb)

**High-concurrency, distributed WebSocket Hub service for the [Descartes](https://github.com/catclever/Descartes) Agent framework.**

> *"Soul in Cloud, Body at Edge"* — Built on top of **[Descartes](https://github.com/catclever/Descartes)**

Descartes Produit acts as the centralized cloud brain for distributed agents. It coordinates the **Cartesian Product ($A \times B$)** between centralized cloud reasoning (powered by [Descartes](https://github.com/catclever/Descartes)) and decentralized edge execution (local developer machines, private shells, databases).

---

## 📖 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Key Features](#-key-features)
- [Installation](#-installation)
- [Configuration (`llm.yml`)](#-configuration-llmyml)
- [Running & Deployment](#-running--deployment)
  - [Standalone CLI](#1-standalone-cli)
  - [Docker Container](#2-docker-container)
  - [Dockge / Docker Compose](#3-dockge--docker-compose)
- [WebSocket Protocol Specification](#-websocket-protocol-specification)
- [Client Integration Example](#-client-integration-example)
- [Running Tests](#-running-tests)
- [License](#-license)

---

## 🏛 Architecture Overview

In traditional agent systems, executing private tools requires giving cloud containers SSH keys, database credentials, or internal network access. Descartes Hub eliminates this vulnerability:

```text
+-------------------------------------------------------------------------+
|                        Descartes Hub (Cloud Brain)                      |
|                                                                         |
|  [LLM Service] <---> [Agent Base] <---> [Dynamic Remote Tool Proxy]     |
|   (DeepSeek/Kimi/GLM)   (ReAct Loop)       (Thread-safe Queue sync)     |
+-------------------------------------------------------------------------+
                                    ▲
                                    │ Bidirectional WebSocket Protocol
                                    ▼
+-------------------------------------------------------------------------+
|                       Edge Client (Local Environment)                   |
|                                                                         |
|  - Declare local tools: Local File, Git, Terminal, Private DB           |
|  - Receive real-time: Thought streaming, Tool Call requests             |
|  - Execute tool locally & reply: {"type": "tool_result", "output": ...} |
+-------------------------------------------------------------------------+
```

1. **Zero-Trust Security**: Cloud containers never receive edge credentials or execution privileges.
2. **Dynamic Toolsets**: Clients declare only the tools needed per job during the handshake, preventing context bloat and tool selection hallucinations.
3. **Synchronous Bridge**: A thread-safe Queue pauses the server agent loop while awaiting remote tool output with timeout protection.

---

## 🌟 Key Features

- **Puma + Faye-WebSocket**: High-throughput non-blocking WebSocket architecture supporting multiple concurrent agent sessions.
- **Task-Driven Tool Scoping**: Handshake-based tool registration (`init`) limits the action space per task.
- **Full Lifecycle Event Streaming**: Real-time broadcasts for thoughts, tool call executions, completion, and errors.
- **Flexible Profile Resolution**: Automatic fallback from `init` payload profile $\rightarrow$ `ENV["DEFAULT_LLM_PROFILE"]` $\rightarrow$ `default` profile in `llm.yml`.
- **Health Check Endpoint**: Built-in `/healthz` HTTP endpoint reporting server status, service version, and active session count.

---

## 🛠 Installation

Add `descartes` and `descartes-produit` to your Gemfile:

```ruby
gem 'descartes', github: 'catclever/Descartes'
gem 'descartes-produit', github: 'catclever/descartes-produit'
```

And install dependencies:

```bash
bundle install
```

---

## ⚙️ Configuration (`llm.yml`)

Configure model endpoints in `llm.yml`:

```yaml
default:
  format: "openai"
  base_url: "http://172.16.51.7:48787/v1"
  model: "deepseek-v4.1-flash"
  api_key: "dummy"
  max_tokens: 8192
  timeout: 120

workbuddy-deepseek:
  format: "openai"
  base_url: "http://172.16.51.7:48787/v1"
  model: "deepseek-v4.1-flash"
  api_key: "dummy"
  max_tokens: 8192
  timeout: 120
```

---

## 🚀 Running & Deployment

### 1. Standalone CLI

Run the server directly using the bundled executable:

```bash
bundle exec bin/descartes-produit --port 8089 --host 0.0.0.0
```

### 2. Docker Container

Build and run using the provided `Dockerfile`:

```bash
docker build -t descartes-produit .
docker run -d -p 8089:8089 -v $(pwd)/llm.yml:/app/llm.yml:ro descartes-produit
```

### 3. Dockge / Docker Compose

Deploy as a stack in **Dockge** or standard Docker Compose using `compose.yaml`:

```yaml
services:
  descartes-produit:
    image: descartes-produit:latest
    build:
      context: .
      dockerfile: Dockerfile
    container_name: descartes-produit
    restart: unless-stopped
    ports:
      - "8089:8089"
    environment:
      - PORT=8089
      - HOST=0.0.0.0
      - DEFAULT_LLM_PROFILE=deepseek_v3
    volumes:
      - ./llm.yml:/app/llm.yml:ro
```

When creating the stack in Dockge:
- **Stack Name**: `descartes-produit`
- **Compose Directory**: `/root/Projects/ruby_lab/descartes-produit` (or repository root)
- **Health Check**: Available at `http://<host>:8089/healthz`

---

## 📡 WebSocket Protocol Specification

The protocol uses standard JSON messages:

| Message Type | Direction | Description |
|---|---|---|
| `init` | Client $\rightarrow$ Hub | Handshake defining task prompt, system prompt, optional `llm_profile`, and dynamic tool schemas |
| `stream_event` | Hub $\rightarrow$ Client | Real-time events (`thought`, `tool_call_start`, `tool_call_end`) |
| `execute_tool` | Hub $\rightarrow$ Client | Request to execute a client-registered tool with `call_id`, `tool`, and `arguments` |
| `tool_result` | Client $\rightarrow$ Hub | Response from edge containing `call_id`, `status`, and `output` |
| `finished` | Hub $\rightarrow$ Client | Terminal event with final task `result` |
| `error` | Hub $\rightarrow$ Client | Error event with failure description |

---

## 💻 Client Integration Example

See `examples/hub_test_client.rb` for a complete reference client using `faye-websocket`.

Run the client:

```bash
bundle exec ruby examples/hub_test_client.rb ws://localhost:8089/
```

---

## 📋 Running Tests

Execute the unit test suite:

```bash
bundle exec rspec
```

---

## 📄 License

Descartes Produit is open-source software licensed under the [MIT License](LICENSE.txt).
