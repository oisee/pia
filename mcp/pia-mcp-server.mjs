#!/usr/bin/env node
/**
 * PIA MCP Server — bridges Claude Code to PIA (ABAP-native coding agent).
 * 
 * Setup: claude mcp add pia -- node /home/alice/dev/pia/mcp/pia-mcp-server.mjs
 * 
 * Tools exposed:
 *   pia_task   — send a task to PIA (read/write/activate ABAP code)
 *   pia_card   — get PIA's agent card (capabilities)
 */
import {readFileSync} from "node:fs";

const PIA_URL = process.env.PIA_URL || "http://localhost:8020/sap/bc/zpia_a2a/";
const AUTH = process.env.PIA_AUTH || "alice:alice";

// --- MCP protocol (JSON-RPC over stdio) ---
const tools = [
  {
    name: "pia_task",
    description: "Send a task to PIA, an ABAP-native coding agent. PIA can read, write and activate ABAP classes inside an OSG/SAP system. Returns the answer and tool trace.",
    inputSchema: {
      type: "object",
      properties: {
        task: { type: "string", description: "The task for PIA (e.g. 'Read class ZCL_FOO and fix method BAR')" }
      },
      required: ["task"]
    }
  },
  {
    name: "pia_card",
    description: "Get PIA's agent card describing its capabilities",
    inputSchema: { type: "object", properties: {} }
  }
];

async function callPIA(task) {
  const body = JSON.stringify({
    message: { role: "user", parts: [{ type: "text", content: task }] }
  });
  const res = await fetch(PIA_URL, {
    method: "POST",
    headers: { "content-type": "application/json", "authorization": "Basic " + btoa(AUTH) },
    body,
    signal: AbortSignal.timeout(120_000)
  });
  if (!res.ok) throw new Error(`PIA HTTP ${res.status}`);
  const data = await res.json();
  let out = `Answer: ${data.answer}\n`;
  out += `Tools: ${data.tool_calls}, Iterations: ${data.iterations}\n`;
  if (data.trace?.length) {
    out += `Trace:\n`;
    for (const t of data.trace) {
      out += `  ${t.tool}: ${t.ok ? "ok" : "FAIL"}\n`;
    }
  }
  return out;
}

async function getCard() {
  const res = await fetch(PIA_URL.replace(/\/$/, "") + "/agent.json", {
    headers: { "authorization": "Basic " + btoa(AUTH) },
    signal: AbortSignal.timeout(5000)
  });
  return JSON.stringify(await res.json(), null, 2);
}

// JSON-RPC over stdio
let buffer = "";
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (line) handle(JSON.parse(line));
  }
});

async function handle(msg) {
  const { id, method, params } = msg;
  try {
    if (method === "initialize") {
      reply(id, { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "pia", version: "0.1.0" } });
    } else if (method === "notifications/initialized") {
      // no response needed
    } else if (method === "tools/list") {
      reply(id, { tools });
    } else if (method === "tools/call") {
      const { name, arguments: args } = params;
      let result;
      if (name === "pia_task") result = await callPIA(args.task);
      else if (name === "pia_card") result = await getCard();
      else throw new Error(`Unknown tool: ${name}`);
      reply(id, { content: [{ type: "text", text: result }] });
    } else if (method === "ping") {
      reply(id, {});
    } else {
      reply(id, null, { code: -32601, message: `Method not found: ${method}` });
    }
  } catch (e) {
    if (id !== undefined) reply(id, null, { code: -32000, message: e.message });
  }
}

function reply(id, result, error) {
  const msg = { jsonrpc: "2.0", id };
  if (error) msg.error = error; else msg.result = result;
  process.stdout.write(JSON.stringify(msg) + "\n");
}
