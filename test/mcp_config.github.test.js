'use strict';

const test = require('node:test');
const assert = require('assert/strict');
const fs = require('fs');
const path = require('path');

function resolveConfigPath() {
  const envPath = process.env.MCP_CONFIG_PATH || process.env.CODEIUM_MCP_CONFIG_PATH;
  if (envPath && fs.existsSync(envPath)) return envPath;

  const home = process.env.USERPROFILE || process.env.HOME || '';
  if (home) {
    const p = path.join(home, '.codeium', 'windsurf', 'mcp_config.json');
    if (fs.existsSync(p)) return p;
  }

  const winUser = process.env.USERNAME;
  if (winUser) {
    const p2 = path.join('C:\\', 'Users', winUser, '.codeium', 'windsurf', 'mcp_config.json');
    if (fs.existsSync(p2)) return p2;
  }

  const demo = path.resolve('C:\\Users\\User\\.codeium\\windsurf\\mcp_config.json');
  return demo;
}

const filePath = resolveConfigPath();

test('mcp_config.json exists at resolved path', () => {
  assert.ok(
    fs.existsSync(filePath),
    `mcp_config.json not found at ${filePath}. Set MCP_CONFIG_PATH to override.`
  );
});

test('github MCP server config shape and values', () => {
  const raw = fs.readFileSync(filePath, 'utf8');
  const config = JSON.parse(raw);

  assert.ok(config && typeof config === 'object', 'config should be an object');
  assert.ok(config.mcpServers && typeof config.mcpServers === 'object', 'mcpServers should be an object');

  const gh = config.mcpServers.github;
  assert.ok(gh && typeof gh === 'object', 'mcpServers.github should exist');

  // serverUrl checks
  assert.equal(
    gh.serverUrl,
    'https://api.githubcopilot.com/mcp/',
    'serverUrl should be https://api.githubcopilot.com/mcp/'
  );
  const url = new URL(gh.serverUrl);
  assert.equal(url.protocol, 'https:', 'serverUrl must use https');

  // headers checks
  assert.ok(gh.headers && typeof gh.headers === 'object', 'headers should exist');
  assert.ok(typeof gh.headers.Authorization === 'string', 'Authorization header should be a string');
  assert.ok(
    /^Bearer\s+\S+$/i.test(gh.headers.Authorization),
    'Authorization must start with "Bearer " followed by a non-empty token or placeholder'
  );
});
