#!/usr/bin/env node
'use strict';

// @runreal/unreal-mcp logs connection retries to stdout, which breaks MCP stdio JSON.
console.log = (...args) => console.error(...args);

require('@runreal/unreal-mcp/dist/bin.js');
