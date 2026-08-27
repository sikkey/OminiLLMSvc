# OminiLLMSvc

语言: [English](README.md) | [中文](README.zh-CN.md)

## 简介

OminiLLMSvc 是一个轻量级代理服务，用于让任意应用适配大语言模型 (LLM) API。它会将请求转发到你选择的模型提供商（例如 OpenAI），并自动处理配置管理。

## 构建与安装

要求：[Node.js](https://nodejs.org/) v16 或更高版本。

```bash
# 克隆仓库
git clone https://github.com/sikkey/OminiLLMSvc.git
cd OminiLLMSvc

# 不需要额外依赖，使用的是 Node.js 自带模块
```

运行平台对应的安装脚本来初始化应用配置，并且不会覆盖已有的自定义配置：

```bash
# Windows
install.bat

# macOS / Linux
bash install.sh
```

安装脚本会从 `template/config/` 目录复制模板文件到 `apps/config/`，只有在目标文件不存在时才会复制，因此你的自定义配置会被保留。

## 配置

应用使用的 JSON 配置文件位于 `apps/config/llm-coder-proxy.config.json`。

这个文件不会被 Git 跟踪（`*.config.json` 位于 `.gitignore` 中）。首次运行时，程序会自动创建 `apps/config` 目录，并从 `template/config/llm-coder-proxy.config.json` 复制模板文件到 `apps/config/llm-coder-proxy.config.json`，随后退出并提示你填写设置。

编辑 `apps/config/llm-coder-proxy.config.json`，至少设置：

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

## 运行

```bash
node apps/llm-coder-proxy.js
```

代理会监听配置中指定的主机和端口（默认：`http://127.0.0.1:7070`）。

健康检查接口：`GET /health` — 返回 `{ "status": "ok" }`。

## 兼容性说明

OminiLLMSvc 适用于 OpenAI 兼容接口，以及常见本地模型运行时，例如 `llama.cpp` 风格插件，以及通用非代码专用模型（如 `gemma4`）。

为了兼容这类环境，代理同时支持：

- `POST /v1/chat/completions`：用于聊天式交互
- `POST /infill` 或 `POST /v1/infill`：用于代码补全 / 插入补全场景

当上游模型没有原生的 infill API 时，OminiLLMSvc 会将请求转换成 chat-completion 形式，并要求模型只补全 prefix 和 suffix 之间缺失的代码片段。这样即使模型本身不是专门的 coder 模型，也可以用于通用代码补全场景。

这使它适用于本地运行时和编辑器集成环境，这些环境通常只暴露 OpenAI 兼容接口，但运行的是通用型模型而非专用代码模型。

## FAQ

**Q: 第一次运行时程序会立即退出。**  
A: 这是正常现象。首次运行时会创建配置文件模板。编辑 `apps/config/llm-coder-proxy.config.json` 填入你的 API Key 和其他设置后，再重新运行即可。

**Q: 我的配置文件保存在哪里？**  
A: `apps/config/llm-coder-proxy.config.json`。这个文件已加入 git 忽略，因此 API Key 不会被提交。

**Q: 如何切换 LLM 提供商或模型？**  
A: 编辑配置文件中的 `llm` 段，修改 `provider`、`baseUrl` 和 `model` 即可。
