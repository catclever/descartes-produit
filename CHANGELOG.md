# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-10-29

### 🚀 Initial Independent Release: Descartes Produit
- **Independent Project Extraction**: Extracted Hub module from `descartes` core gem into standalone `descartes-produit` directory, service, and gem.
- **Descartes::Hub::Server & Session**: High-concurrency Puma-powered WebSocket Hub server to coordinate distributed agent sessions under the "Soul in Cloud, Body at Edge" architecture.
- **Task-Driven Dynamic Toolsets**: Dynamic declaration and scoping of tools per task via WebSocket handshake (`init`).
- **Descartes::Hub::Protocol**: Comprehensive protocol specification and parser for bidirectional JSON messages (`init`, `execute_tool`, `tool_result`, `stream_event`, `finished`, `error`).
- **Health Check Endpoint**: `/healthz` HTTP health check with status, service identity, and active session count.
- **Standalone CLI**: `bin/descartes-produit` for running the Hub server with customizable host and port options.
- **Containerization & Dockge**: Standalone `Dockerfile` and `compose.yaml` configured for independent deployment.
- **Client Reference**: End-to-end WebSocket client example in `examples/hub_test_client.rb`.
