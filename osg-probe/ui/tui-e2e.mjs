// End-to-end UI test of the PIA terminal: red -> fix -> green, in English, Danish and Russian.
// usage: node tui-e2e.mjs [base-url] [lang,...]   default: A4H, en,da,ru
// Credentials: the a4h-vsp entry of ~/dev/pia/.mcp.json (never printed). Screenshots: ./shots/<lang>-<n>-<step>.png
import {readFileSync, mkdirSync} from "node:fs";
import {createRequire} from "node:module";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";
const {chromium} = createRequire("/home/alice/dev/osg-pia/package.json")("playwright");
const here = dirname(fileURLToPath(import.meta.url));
const base = process.argv[2] || "http://192.168.8.105:50000/sap/bc/zpia_tui/?sap-client=001";
const langs = (process.argv[3] || "en,da,ru").split(",");
// credentials: PIA_E2E_USER/PIA_E2E_PASS, else the a4h-vsp entry of .mcp.json; class: PIA_E2E_CLASS
let creds;
if (process.env.PIA_E2E_USER) creds = {username: process.env.PIA_E2E_USER, password: process.env.PIA_E2E_PASS ?? ""};
else { const cfg = JSON.parse(readFileSync("/home/alice/dev/pia/.mcp.json", "utf8")).mcpServers["a4h-vsp"];
  creds = {username: cfg.args[cfg.args.indexOf("--user") + 1], password: cfg.env.SAP_PASSWORD}; }
const CLS = process.env.PIA_E2E_CLASS || "ZCL_PIA_DEMO4";
const SHOTS = process.env.PIA_E2E_SHOTS || "shots";
const STEPS = {
  en: [["green", `Run the tests of ${CLS}.`, /pass|green|passed/i],
       ["break", `In ${CLS}, change add to a - b and activate it.`, /activat/i],
       ["red", `Run the tests of ${CLS} again.`, /-1|1-|fail|red/i],
       ["fix", `Change add back to a + b, activate and run the tests.`, /pass|green|passed/i]],
  da: [["green", `Kør testene for ${CLS}.`, /pass|grøn|bestået|lykkedes/i],
       ["break", `I ${CLS}: ændr add til a - b og aktiver klassen.`, /aktiv/i],
       ["red", `Kør testene for ${CLS} igen.`, /-1|1-|fejl|fail|rød/i],
       ["fix", `Ændr add tilbage til a + b, aktiver og kør testene.`, /pass|grøn|bestået|lykkedes/i]],
  ru: [["green", `Запусти тесты ${CLS}.`, /pass|green|зелён|прош|пройден|успешн/i],
       ["break", `В ${CLS} замени в add сложение на вычитание (a - b) и активируй.`, /активир/i],
       ["red", `Запусти тесты ${CLS} ещё раз.`, /-1|1-|упал|fail|красн/i],
       ["fix", `Верни a + b, активируй и запусти тесты.`, /pass|green|зелён|прош|пройден|успешн/i]],
};
mkdirSync(join(here, SHOTS), {recursive: true});
const b = await chromium.launch({executablePath: "/home/alice/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome"});
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
    const ok = expect.test(turn);
    if (!ok) failed++;
    await p.screenshot({path: join(here, SHOTS, `${lang}-${n}-${step}.png`)});
    console.log(`${lang} ${n} ${step.padEnd(5)} ${ok ? "OK  " : "FAIL"} ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  }
  await ctx.close();
}
await b.close();
console.log(failed ? `${failed} step(s) failed` : "all steps passed");
process.exit(failed ? 1 : 0);
