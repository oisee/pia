// End-to-end UI test of the PIA terminal: green -> break -> red -> fix -> green, in English, Danish and Russian.
// Five turns, because on open-steamgate an activation publishes at the end of the turn (tests run in the next one).
// usage: node tui-e2e.mjs <terminal-url> [lang,...]   e.g. http://127.0.0.1:8020/sap/bc/zpia_tui/ en,da,ru
// Credentials: PIA_E2E_USER / PIA_E2E_PASS (else the a4h-vsp entry of this repository's .mcp.json; never printed).
// Playwright comes from the open-steamgate tree (OSG=..., default ~/dev/osg-pia; `npx playwright install chromium`
// there once); PIA_E2E_CHROME=<path> picks another Chromium. Screenshots: ./shots/<lang>-<n>-<step>.png
// Replay: each language has its own transcript (replay/pia-chapter.<lang>.rec), so run one language per replay.
import {readFileSync, mkdirSync, existsSync} from "node:fs";
import {homedir} from "node:os";
import {createRequire} from "node:module";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";
const osg = process.env.OSG || join(homedir(), "dev", "osg-pia");
let chromium;
try { ({chromium} = createRequire(join(osg, "package.json"))("playwright")); }
catch (e) { console.log(`playwright not found in ${osg} (set OSG=<open-steamgate tree>, run npm ci there)`); process.exit(2); }
const here = dirname(fileURLToPath(import.meta.url));
const base = process.argv[2];
if (!base) { console.log("usage: node tui-e2e.mjs <terminal-url> [lang,...]"); process.exit(2); }
const langs = (process.argv[3] || "en,da,ru").split(",");
// credentials: PIA_E2E_USER/PIA_E2E_PASS, else the a4h-vsp entry of .mcp.json; class: PIA_E2E_CLASS
let creds;
if (process.env.PIA_E2E_USER) creds = {username: process.env.PIA_E2E_USER, password: process.env.PIA_E2E_PASS ?? ""};
else if (existsSync(join(here, "..", "..", ".mcp.json"))) {
  const cfg = JSON.parse(readFileSync(join(here, "..", "..", ".mcp.json"), "utf8")).mcpServers["a4h-vsp"];
  creds = {username: cfg.args[cfg.args.indexOf("--user") + 1], password: cfg.env.SAP_PASSWORD}; }
else { console.log("set PIA_E2E_USER and PIA_E2E_PASS"); process.exit(2); }
const CLS = process.env.PIA_E2E_CLASS || "ZCL_PIA_DEMO";
const SHOTS = process.env.PIA_E2E_SHOTS || "shots";
const SETTLE = Number(process.env.PIA_E2E_SETTLE || 0);
const STEPS = {
  en: [["green", `Run the tests of ${CLS}.`, /pass|green|passed/i],
       ["break", `In ${CLS}, change add to a - b and activate it.`, /activat/i],
       ["red", `Run the tests of ${CLS} again.`, /[-−]1|1-|fail|red/i],
       ["fix", `Change add back to a + b and activate it.`, /activat/i],
       ["green2", `Run the tests of ${CLS} once more.`, /pass|green|passed/i]],
  da: [["green", `Kør testene for ${CLS}.`, /pass|grøn|bestået|lykkedes/i],
       ["break", `I ${CLS}: ændr add til a - b og aktiver klassen.`, /aktiv/i],
       ["red", `Kør testene for ${CLS} igen.`, /[-−]1|1-|fejl|fail|rød|red/i],
       ["fix", `Ændr add tilbage til a + b og aktiver klassen.`, /aktiv/i],
       ["green2", `Kør testene for ${CLS} en gang til.`, /pass|grøn|bestået|lykkedes/i]],
  ru: [["green", `Запусти тесты ${CLS}.`, /pass|green|зелён|прош|пройден|успешн/i],
       ["break", `В ${CLS} замени в add сложение на вычитание (a - b) и активируй.`, /активир/i],
       ["red", `Запусти тесты ${CLS} ещё раз.`, /[-−]1|1-|упал|fail|красн|red/i],
       ["fix", `Верни a + b и активируй.`, /активир/i],
       ["green2", `Запусти тесты ${CLS} ещё раз.`, /pass|green|зелён|прош|пройден|успешн/i]],
};
mkdirSync(join(here, SHOTS), {recursive: true});
let b;
try { b = await chromium.launch(process.env.PIA_E2E_CHROME ? {executablePath: process.env.PIA_E2E_CHROME} : {}); }
catch (e) { console.log(`no browser: ${e.message.split("\n")[0]}\nrun \`npx playwright install chromium\` in ${osg}, or set PIA_E2E_CHROME`); process.exit(2); }
let failed = 0;
for (const lang of langs) {
  const ctx = await b.newContext({viewport: {width: 1100, height: 760}, httpCredentials: creds});  // fresh session id per language
  const p = await ctx.newPage();
  await p.goto(base, {waitUntil: "networkidle"});
  // whole xterm buffer (scrollback included), not only the visible rows
  const text = () => p.evaluate(() => { const b = term.buffer.active, out = [];
    for (let i = 0; i < b.length; i++) out.push(b.getLine(i)?.translateToString(true) ?? ""); return out.join("\n"); });
  await p.waitForFunction(() => /Type a task/.test(document.querySelector(".xterm-rows")?.innerText ?? ""), null, {timeout: 30000});
  await p.click("#terminal");
  let n = 0;
  for (const [step, prompt, expect] of STEPS[lang]) {
    n++;
    const mark = (await text()).length;
    const t0 = Date.now();
    await p.keyboard.type(prompt);
    await p.keyboard.press("Enter");
    try {
      // a turn is over when the client's status line is gone and nothing is queued (st, queued: page globals)
      await p.waitForFunction(() => st !== null, null, {timeout: 15000});
      await p.waitForFunction(() => st === null && queued.length === 0, null, {timeout: 180000});
    } catch (e) {
      await p.screenshot({path: join(here, SHOTS, `${lang}-${n}-${step}-TIMEOUT.png`)});
      console.log(`${lang} ${n} ${step} TIMEOUT; screen:\n${(await text()).slice(-1500)}`);
      failed++; break;
    }
    await p.waitForTimeout(400);
    const turn = (await text()).slice(mark);
    // a dropped connection ends the turn too, and the replayed history can then match: count it as a failure
    const ok = expect.test(turn) && !/Disconnected/.test(turn);
    if (!ok) failed++;
    await p.screenshot({path: join(here, SHOTS, `${lang}-${n}-${step}.png`)});
    console.log(`${lang} ${n} ${step.padEnd(5)} ${ok ? "OK  " : "FAIL"} ${((Date.now() - t0) / 1000).toFixed(1)}s`);
    // open-steamgate publishes an activation after the turn and swaps the runtime, which drops the
    // WebSocket; a person types slower than that, the test waits (PIA_E2E_SETTLE ms, 0 on SAP)
    if (SETTLE && (step === "break" || step === "fix")) await p.waitForTimeout(SETTLE);
  }
  await ctx.close();
}
await b.close();
console.log(failed ? `${failed} step(s) failed` : "all steps passed");
process.exit(failed ? 1 : 0);
