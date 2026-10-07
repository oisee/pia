// One live take, no replay, no retries: a fresh session, two turns (read the chapter section, then the question),
// a screenshot after the second turn, and the full record (WebSocket frames, terminal text).
// usage: OSG=<tree> PIA_E2E_USER=… PIA_E2E_PASS=… node featured-run.mjs <terminal-url> <read.txt> <ask.txt> <out-dir>
import {readFileSync, writeFileSync, mkdirSync, appendFileSync} from "node:fs";
import {createRequire} from "node:module";
import {join} from "node:path";
import {homedir} from "node:os";
const {chromium} = createRequire(join(process.env.OSG || join(homedir(), "dev", "osg-pia"), "package.json"))("playwright");
const [url, readFile, askFile, out] = process.argv.slice(2);
mkdirSync(out, {recursive: true});
const frames = join(out, "frames.jsonl"); writeFileSync(frames, "");
const t0 = Date.now();
const log = (dir, data) => appendFileSync(frames, JSON.stringify({ms: Date.now() - t0, dir, data: String(data)}) + "\n");
const b = await chromium.launch();
const ctx = await b.newContext({viewport: {width: 1100, height: 760}, deviceScaleFactor: 2,
  httpCredentials: {username: process.env.PIA_E2E_USER, password: process.env.PIA_E2E_PASS ?? ""}});
const p = await ctx.newPage();
p.on("websocket", ws => { ws.on("framesent", f => log("sent", f.payload)); ws.on("framereceived", f => log("recv", f.payload)); });
await p.goto(url, {waitUntil: "networkidle"});
await p.evaluate(() => { try { localStorage.clear(); } catch (e) {} });   // a fresh session id
await p.reload({waitUntil: "networkidle"});
await p.waitForFunction(() => /Type a task/.test(document.querySelector(".xterm-rows")?.innerText ?? ""), null, {timeout: 60000});
await p.click("#terminal");
for (const [i, f] of [[1, readFile], [2, askFile]]) {
  const text = readFileSync(f, "utf8").trim();
  await p.evaluate(t => typeText(t), text);
  await p.keyboard.press("Enter");
  await p.waitForFunction(() => st !== null, null, {timeout: 15000});
  await p.waitForFunction(() => st === null, null, {timeout: 15 * 60 * 1000, polling: 500});
  await p.waitForTimeout(500);
  await p.screenshot({path: join(out, `turn-${i}.png`)});
}
const all = await p.evaluate(() => { const b = term.buffer.active, o = [];
  for (let i = 0; i < b.length; i++) o.push(b.getLine(i)?.translateToString(true) ?? ""); return o.join("\n"); });
writeFileSync(join(out, "terminal.txt"), all);
console.log(`done in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
await b.close();
