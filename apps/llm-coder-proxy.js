#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const APPS_DIR = __dirname;
const CONFIG_DIR = path.join(APPS_DIR, 'config');
const CONFIG_FILE = path.join(CONFIG_DIR, 'llm-coder-proxy.config.json');
const TEMPLATE_CONFIG = path.join(APPS_DIR, '..', 'template', 'config', 'llm-coder-proxy.config.json');

/**
 * Ensure the config file exists. If not, copy from the template.
 */
function ensureConfig() {
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
  }

  if (!fs.existsSync(CONFIG_FILE)) {
    if (!fs.existsSync(TEMPLATE_CONFIG)) {
      console.error('Template config not found:', TEMPLATE_CONFIG);
      process.exit(1);
    }
    fs.copyFileSync(TEMPLATE_CONFIG, CONFIG_FILE);
    console.log('Config file created from template:', CONFIG_FILE);
    console.log('Please edit the config file and set your API key and other options, then restart.');
    process.exit(0);
  }
}

/**
 * Load and parse the config file.
 * @returns {object}
 */
function loadConfig() {
  const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
  return JSON.parse(raw);
}

/**
 * Forward request to the configured LLM provider.
 * @param {http.IncomingMessage} req
 * @param {http.ServerResponse} res
 * @param {string} body
 * @param {object} config
 */
function parseJsonBody(rawBody) {
  if (!rawBody) {
    return {};
  }

  try {
    return JSON.parse(rawBody);
  } catch (err) {
    return {};
  }
}

function normalizeInfillPayload(data, config) {
  const prefix = data.input_prefix ?? data.prefix ?? data.prompt ?? data.input ?? '';
  const suffix = data.input_suffix ?? data.suffix ?? '';
  const maxTokens = Number(data.max_tokens ?? data.n_predict ?? 256);
  const temperature = Number(data.temperature ?? 0.2);

  const systemPrompt = 'You are completing the missing portion of source code. Return only the missing code, with no explanation, markdown fences, or surrounding text.';
  const userPrompt = [
    'Complete the missing code between the prefix and suffix.',
    'Return only the missing code content.',
    'Prefix:',
    String(prefix),
    'Suffix:',
    String(suffix),
  ].join('\n');

  return JSON.stringify({
    model: config.llm.model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    max_tokens: Number.isFinite(maxTokens) && maxTokens > 0 ? maxTokens : 256,
    temperature: Number.isFinite(temperature) ? temperature : 0.2,
  });
}

function handleRequest(req, res, body, config) {
  const { apiKey, baseUrl } = config.llm;

  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  const reqPath = req.url.startsWith('/') ? req.url : '/' + req.url;
  const rawPath = reqPath.split('?')[0];
  const isInfill = rawPath === '/infill' || rawPath === '/v1/infill';
  const targetPath = isInfill ? '/v1/chat/completions' : reqPath;
  const targetUrl = new URL(base + targetPath);
  const forwardedHeaders = Object.assign({}, req.headers, {
    'Authorization': 'Bearer ' + apiKey,
    'host': targetUrl.host,
  });
  const options = {
    hostname: targetUrl.hostname,
    port: targetUrl.port || (targetUrl.protocol === 'https:' ? 443 : 80),
    path: targetUrl.pathname + targetUrl.search,
    method: req.method,
    headers: forwardedHeaders,
  };

  const transport = targetUrl.protocol === 'https:' ? https : http;

  const proxyReq = transport.request(options, (proxyRes) => {
    if (isInfill) {
      let upstreamBody = '';
      proxyRes.on('data', (chunk) => {
        upstreamBody += chunk.toString();
      });
      proxyRes.on('end', () => {
        try {
          const parsed = JSON.parse(upstreamBody || '{}');
          let content = '';

          if (parsed && Array.isArray(parsed.choices) && parsed.choices[0]?.message?.content) {
            content = parsed.choices[0].message.content;
          } else if (parsed && Array.isArray(parsed.choices) && typeof parsed.choices[0]?.text === 'string') {
            content = parsed.choices[0].text;
          } else if (typeof parsed?.content === 'string') {
            content = parsed.content;
          } else if (typeof parsed?.output_text === 'string') {
            content = parsed.output_text;
          } else {
            content = upstreamBody || '';
          }

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            content,
            model: config.llm.model,
            ok: true,
          }));
        } catch (err) {
          res.writeHead(502, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Bad Gateway', message: err.message }));
        }
      });
      return;
    }

    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy request error:', err.message);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Bad Gateway', message: err.message }));
  });

  if (body) {
    const requestBody = isInfill ? normalizeInfillPayload(parseJsonBody(body), config) : body;
    proxyReq.write(requestBody);
  }
  proxyReq.end();
}

/**
 * Start the LLM coder proxy server.
 * @param {object} config
 */
function startServer(config) {
  const host = config.server && config.server.host ? config.server.host : '127.0.0.1';
  const port = config.server && config.server.port ? config.server.port : 7070;

  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
      return;
    }

const MAX_BODY_SIZE = 10 * 1024 * 1024; // 10 MB

    let body = '';
    let bodySize = 0;
    req.on('data', (chunk) => {
      bodySize += chunk.length;
      if (bodySize > MAX_BODY_SIZE) {
        res.writeHead(413, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Payload Too Large' }));
        req.destroy();
        return;
      }
      body += chunk;
    });
    req.on('end', () => {
      handleRequest(req, res, body, config);
    });
  });

  server.listen(port, host, () => {
    console.log('LLM Coder Proxy listening on http://' + host + ':' + port);
  });
}

// ---- Main ----
ensureConfig();
const config = loadConfig();
startServer(config);
