// Drives the nixbox zellij web terminal in a headless browser and records a
// video of a demo scenario. Used by the `nixbox-demo` script (see
// modules/devenv.nix, nixbox.playwright.enable). See the project README and the
// "zellij web + Playwright" notes for the flow this automates.
//
// Env in:
//   NIXBOX_TOKEN      zellij web login token (required)
//   NIXBOX_WEB_PORT   web server port (default 8920)
//   DEMO_OUT          dir to write the recorded .webm (required)
//   DEMO_SESSION      session name to create (default "nixbox")
//   DEMO_STEPS        JSON array of steps run once nvim is up (see below)
//   DEMO_VIEWPORT     "WxH" (default 1000x600)
//
// A step is one of:
//   { "type": "text",  "value": ":e README.md", "wait": 1200 }   // types literal text
//   { "press": "Enter", "wait": 800 }                            // presses a key
//   { "shot":  "name", "wait": 0 }                               // screenshot DEMO_OUT/name.png
//   { "wait":  2000 }                                            // just wait (ms)
const { chromium } = require('@playwright/test');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const PORT = process.env.NIXBOX_WEB_PORT || '8920';
  const TOKEN = process.env.NIXBOX_TOKEN;
  const OUT = process.env.DEMO_OUT;
  const SESSION = process.env.DEMO_SESSION || 'nixbox';
  const [vw, vh] = (process.env.DEMO_VIEWPORT || '1000x600').split('x').map(Number);
  const steps = JSON.parse(process.env.DEMO_STEPS || '[]');
  if (!TOKEN || !OUT) { console.error('NIXBOX_TOKEN and DEMO_OUT are required'); process.exit(2); }

  const browser = await chromium.launch({
    headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox'],
  });
  const ctx = await browser.newContext({
    viewport: { width: vw, height: vh },
    recordVideo: { dir: OUT, size: { width: vw, height: vh } },
  });
  const page = await ctx.newPage();
  const shot = (n) => page.screenshot({ path: `${OUT}/${n}.png` });

  try {
    await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: 'domcontentloaded' });
    // auth
    await page.waitForSelector('#token', { timeout: 20000 });
    await page.fill('#token', TOKEN);
    await page.keyboard.press('Enter');
    await page.waitForSelector('#terminal', { timeout: 20000 });
    await sleep(3500);
    // session wizard: name -> Enter (to layout step) -> Enter (nvim layout, create)
    await page.keyboard.type(SESSION);
    await sleep(900);
    await page.keyboard.press('Enter');
    await sleep(1500);
    await page.keyboard.press('Enter');
    await sleep(4500); // session created + nvim layout loads
    // zellij shows a one-time release-notes floating pane on first run of a
    // version — dismiss it (<Esc>) so the nvim layout is visible.
    await page.keyboard.press('Escape');
    await sleep(1500);
    // clear any nvim startup "hit-enter" / paginated message (some plugins emit
    // a startup notice); a few Enters exhaust it, then Escape back to normal.
    for (let i = 0; i < 4; i++) { await page.keyboard.press('Enter'); await sleep(400); }
    await page.keyboard.press('Escape');
    await sleep(1500);
    await shot('00-nvim');
    // scenario steps
    for (const s of steps) {
      if (s.type) await page.keyboard.type(s.type, { delay: 35 });
      if (s.press) await page.keyboard.press(s.press);
      if (s.shot) await shot(s.shot);
      await sleep(s.wait != null ? s.wait : 1000);
    }
    await sleep(1500);
  } finally {
    await ctx.close(); // flush video
    await browser.close();
  }
  console.log('demo: recorded video in', OUT);
})().catch((e) => { console.error(e); process.exit(1); });
