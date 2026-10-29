# Descartes Produit (中文文档)

[![Ruby](https://img.shields.io/badge/Language-Ruby-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-0.2.0-green.svg)](lib/descartes/hub/version.rb)

**面向 Descartes Agent 框架的高并发分布式 WebSocket 服务中心。**

> *"Soul in Cloud, Body at Edge"（云端构筑灵魂，边缘驱动肉身）*

Descartes Produit 将 AI Agent 的推理中枢与端侧执行完全解耦：LLM 推理、会话状态机与 ReAct 循环集中运行于云端 Hub，而敏感私有工具执行与系统权限完全保留在边缘客户端。

---

## 🏛 架构全景

```text
+-------------------------------------------------------------------------+
|                        Descartes Hub (云端大脑)                         |
|                                                                         |
|  [LLM Service] <---> [Agent Base] <---> [Dynamic Remote Tool Proxy]     |
|   (DeepSeek/Kimi/GLM)   (ReAct Loop)       (线程安全队列同步)           |
+-------------------------------------------------------------------------+
                                    ▲
                                    │ 双向 WebSocket 协议
                                    ▼
+-------------------------------------------------------------------------+
|                       边缘客户端 (本地运行环境)                         |
|                                                                         |
|  - 动态声明端侧工具: 本地文件、Git、终端执行、内网私有库                 |
|  - 实时接收: 思维流 (thought)、工具调用请求 (execute_tool)              |
|  - 端侧执行工具并回传: {"type": "tool_result", "output": ...}           |
+-------------------------------------------------------------------------+
```

1. **零信任安全架构**：云端容器无需暴露任何本地私钥、SSH 凭据或私网数据库连接。
2. **任务驱动的动态工具集 (Task-Driven Dynamic Toolsets)**：握手时按需注册工具，极大削减 Prompt Token 消耗并消除模型幻觉。
3. **线程级安全同步**：基于 `Queue` 的挂起恢复机制，支持超时保护。

---

## 🛠 安装指南

在项目的 `Gemfile` 中添加：

```ruby
gem 'descartes-produit', path: '../descartes-produit'
# 或引用 GitHub:
# gem 'descartes-produit', github: 'catclever/descartes-produit'
```

然后执行：

```bash
bundle install
```

---

## ⚙️ 模型配置 (`llm.yml`)

```yaml
default:
  format: "openai"
  base_url: "http://172.16.51.7:48787/v1"
  model: "deepseek-v4.1-flash"
  api_key: "dummy"
  max_tokens: 8192
  timeout: 120
```

---

## 🚀 启动与部署

### 1. 独立命令行 (CLI)

```bash
bundle exec bin/descartes-produit --port 8089 --host 0.0.0.0
```

### 2. Docker 镜像部署

```bash
docker build -t descartes-produit .
docker run -d -p 8089:8089 -v $(pwd)/llm.yml:/app/llm.yml:ro descartes-produit
```

### 3. Dockge / Docker Compose 部署

通过 Dockge 或 Docker Compose 部署，使用独立的 `compose.yaml`：

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

在 Dockge 中配置 Stack：
- **Stack 目录 / 上下文**：指向 `/root/Projects/ruby_lab/descartes-produit`
- **健康检查**：`GET http://<host>:8089/healthz`

---

## 📡 WebSocket 协议格式

| 消息类型 | 传输方向 | 说明 |
|---|---|---|
| `init` | 客户端 $\rightarrow$ Hub | 初始化会话、传入 Prompt、可选模型 Profile 与工具 Schema 列表 |
| `stream_event` | Hub $\rightarrow$ 客户端 | 实时事件（`thought`, `tool_call_start`, `tool_call_end`） |
| `execute_tool` | Hub $\rightarrow$ 客户端 | 请求端侧执行指定工具（附带 `call_id`, `tool`, `arguments`） |
| `tool_result` | 客户端 $\rightarrow$ Hub | 端侧回传执行结果（`call_id`, `status`, `output`） |
| `finished` | Hub $\rightarrow$ 客户端 | 任务顺利完成终态及最终执行结果 |
| `error` | Hub $\rightarrow$ 客户端 | 异常终止信息 |

---

## 📋 运行测试

```bash
bundle exec rspec
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE.txt) 开源。
