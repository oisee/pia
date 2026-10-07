// F1 driver: opens PIA's terminal, sends one task in /auto mode and records everything until PIA says PIA-DONE
// or the turn limit is reached. No input after the task: the terminal itself sends "Continue with the task."
// usage: OSG=<tree> PIA_E2E_USER=… PIA_E2E_PASS=… node f1-run.mjs <terminal-url> <task-file> <out-dir>
import {readFileSync, writeFileSync, mkdirSync, appendFileSync} from "node:fs";
import {createRequire} from "node:module";
import {join} from "node:path";
import {homedir} from "node:os";
const {chromium} = createRequire(join(process.env.OSG || join(homedir(), "dev", "osg-pia"), "package.json"))("playwright");
const [url, taskFile, out] = process.argv.slice(2);
const task = readFileSync(taskFile, "utf8").trim().replace(/\s+/g, " ");
mkdirSync(out, {recursive: true});
const frames = join(out, "frames.jsonl");
writeFileSync(frames, "");
const t0 = Date.now();
const log = (dir, data) => appendFileSync(frames, JSON.stringify({ms: Date.now() - t0, dir, data: String(data)}) + "\n");
const b = await chromium.launch();
const ctx = await b.newContext({viewport: {width: 1200, height: 900},
  httpCredentials: {username: process.env.PIA_E2E_USER, password: process.env.PIA_E2E_PASS ?? ""}});
const p = await ctx.newPage();
p.on("websocket", ws => { ws.on("framesent", f => log("sent", f.payload)); ws.on("framereceived", f => log("recv", f.payload));
  ws.on("close", () => log("close", "")); });
await p.goto(url, {waitUntil: "networkidle"});
await p.waitForFunction(() => /Type a task/.test(document.querySelector(".xterm-rows")?.innerText ?? ""), null, {timeout: 60000});
await p.evaluate(() => { localStorage.removeItem("pia-hist"); });
await p.click("#terminal");
// the task goes in as pasted text, then Enter: exactly what a user would do
await p.evaluate(t => typeText("/auto " + t), task);
await p.keyboard.press("Enter");
await p.waitForFunction(() => auto !== null, null, {timeout: 15000});
await p.waitForFunction(() => auto === null && st === null, null, {timeout: 60 * 60 * 1000, polling: 1000});
const text = await p.evaluate(() => { const b = term.buffer.active, o = [];
  for (let i = 0; i < b.length; i++) o.push(b.getLine(i)?.translateToString(true) ?? ""); return o.join("\n"); });
writeFileSync(join(out, "terminal.txt"), text);
writeFileSync(join(out, "task.txt"), task + "\n");
await p.screenshot({path: join(out, "end.png")});
console.log(`done in ${((Date.now() - t0) / 1000).toFixed(0)} s; ${/PIA-DONE/.test(text) ? "PIA-DONE" : "no PIA-DONE"}`);
await b.close();
