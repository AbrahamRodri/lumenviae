// End-to-end browser smoke test for the Rosary-only website.
// Run it through scripts/e2e/run.sh (see README.md); BASE_URL picks the server.
//
// Selectors are role and text based on purpose: the pages are redesigned
// often and their CSS classes are not a contract.
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const BASE_URL = (process.env.BASE_URL || "http://localhost:8096").replace(/\/$/, "");
const OUT_DIR = path.join(__dirname, "out");

const VIEWPORTS = [
  { name: "narrow", width: 320, height: 568 },
  { name: "mobile", width: 390, height: 844 },
  { name: "desktop", width: 1280, height: 800 },
];

const PAGES = [
  { path: "/", slug: "home" },
  { path: "/mysteries", slug: "mysteries" },
  { path: "/mysteries/joyful", slug: "mysteries-joyful" },
  { path: "/mysteries/seven_sorrows", slug: "mysteries-seven-sorrows" },
  { path: "/privacy-policy", slug: "privacy-policy" },
];

const RETIRED = ["/dashboard", "/app", "/rosary-methods", "/true-devotion", "/saint-carlo", "/feedback"];

const failures = [];
let checks = 0;

function check(ok, label, detail) {
  checks += 1;
  if (ok) {
    console.log(`  ok    ${label}`);
  } else {
    failures.push(detail ? `${label}: ${detail}` : label);
    console.log(`  FAIL  ${label}${detail ? ` (${detail})` : ""}`);
  }
}

// Waits for LiveView to finish connecting without depending on any class
// the page might change; a page with no socket simply times out quietly.
async function settle(page) {
  await page.waitForLoadState("load");
  await page.waitForLoadState("networkidle", { timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(300);
}

async function fullPageShot(page, name) {
  await page.screenshot({ path: path.join(OUT_DIR, `${name}.png`), fullPage: true });
}

async function noHorizontalScroll(page, label) {
  const { scrollWidth, innerWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  check(scrollWidth <= innerWidth, `${label}: no horizontal scroll`, `scrollWidth ${scrollWidth} > innerWidth ${innerWidth}`);
}

async function checkPage(page, errors, vp, spec) {
  const label = `${vp.name} ${spec.path}`;
  console.log(label);
  errors.length = 0;

  const response = await page.goto(BASE_URL + spec.path);
  await settle(page);

  check(response && response.status() === 200, `${label}: status 200`, `got ${response && response.status()}`);
  const h1 = await page.getByRole("heading", { level: 1 }).count();
  check(h1 >= 1, `${label}: has an h1`);
  await noHorizontalScroll(page, label);
  await fullPageShot(page, `${vp.name}-${spec.slug}`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
}

async function checkPrayFlow(page, errors, vp) {
  const label = `${vp.name} pray flow`;
  console.log(label);
  errors.length = 0;

  await page.goto(`${BASE_URL}/mysteries/joyful`);
  await settle(page);

  // The set cards name their link after the set, so find it by address.
  const prayLink = page.locator('a[href^="/meditation-sets/"][href*="/pray"]').first();
  check((await prayLink.count()) > 0, `${label}: a Pray link exists on /mysteries/joyful`);
  if ((await prayLink.count()) === 0) return;

  await Promise.all([page.waitForURL(/\/meditation-sets\/[^/]+\/pray/), prayLink.click()]);
  await settle(page);
  check(/\/meditation-sets\/[^/]+\/pray/.test(page.url()), `${label}: landed on a prayer page`, page.url());
  check((await page.getByRole("heading", { level: 1 }).count()) >= 1, `${label}: prayer page has an h1`);
  await noHorizontalScroll(page, label);
  await fullPageShot(page, `${vp.name}-pray-start`);

  // Two presses, because the first may only leave an introduction.
  const before = await page.evaluate(() => document.body.innerText);
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(600);
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(600);
  const after = await page.evaluate(() => document.body.innerText);
  check(before !== after, `${label}: ArrowRight moves the prayer forward`);
  await noHorizontalScroll(page, `${label} after ArrowRight`);
  await fullPageShot(page, `${vp.name}-pray-after-arrow`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
}

async function checkRedirects(page, vp) {
  for (const retired of RETIRED) {
    const label = `${vp.name} ${retired}`;
    console.log(label);
    await page.goto(BASE_URL + retired);
    await settle(page);
    const { pathname } = new URL(page.url());
    check(pathname === "/", `${label}: redirects to /`, `ended at ${pathname}`);
  }
}


// Polls until `fn` returns something truthy; LiveView patches and the hooks
// that restore saved choices land a moment after the page loads.
async function eventually(fn, timeout = 5000) {
  const deadline = Date.now() + timeout;
  for (;;) {
    let value;
    try {
      value = await fn();
    } catch (_err) {
      value = false;
    }
    if (value || Date.now() > deadline) return value;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

// A page in a fresh context, so saved choices and text sizes never leak
// from one flow into the next.
async function freshPage(browser, vp, errors) {
  const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
  const page = await context.newPage();
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(`${msg.text()} @ ${msg.location().url}`);
  });
  page.on("pageerror", (err) => errors.push(`pageerror: ${err.message}`));
  return { context, page };
}

const PRAY_LINK = 'a[href^="/meditation-sets/"][href*="/pray"]';

async function firstSetPath(page) {
  await page.goto(`${BASE_URL}/mysteries/joyful`);
  await settle(page);
  const href = await page.locator(PRAY_LINK).first().getAttribute("href");
  return href.split("?")[0];
}

// What the live region says about the bead the reader is on.
function beadStatus(page) {
  return page.locator('[aria-live="polite"][aria-atomic="true"]').first().innerText();
}

async function checkCategoryChoices(browser, vp) {
  const label = `${vp.name} category choices`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const radio = (name) => page.getByRole("radio", { name, exact: true });
  const choose = async (name) => {
    await page.getByText(name, { exact: true }).click();
    await page.waitForTimeout(300);
  };
  const prayHrefs = () => page.locator(PRAY_LINK).evaluateAll((links) => links.map((a) => a.getAttribute("href")));
  const countingShown = async () => (await page.getByRole("group", { name: "Counting" }).count()) > 0;

  await page.goto(`${BASE_URL}/mysteries/joyful`);
  await settle(page);
  check(await countingShown(), `${label}: Counting shows while the audio is meditation only`);

  await choose("Whole Rosary aloud");
  check(await radio("Whole Rosary aloud").isChecked(), `${label}: Whole Rosary aloud is selected`);
  check(!(await countingShown()), `${label}: Counting disappears with the whole Rosary aloud`);
  const aloudHrefs = await prayHrefs();
  check(aloudHrefs.length > 0 && aloudHrefs.every((h) => h.includes("aloud=true")), `${label}: Pray links gain aloud=true`, aloudHrefs[0]);
  await noHorizontalScroll(page, `${label} (aloud)`);

  await page.reload();
  await settle(page);
  check(
    await eventually(() => radio("Whole Rosary aloud").isChecked()),
    `${label}: the whole Rosary aloud persists across a reload`
  );

  await choose("Meditation only");
  check(await eventually(countingShown), `${label}: Counting returns with meditation only`);

  await choose("On the screen");
  check(await radio("On the screen").isChecked(), `${label}: On the screen is selected`);
  const screenHrefs = await prayHrefs();
  check(screenHrefs.length > 0 && screenHrefs.every((h) => h.includes("count=screen")), `${label}: Pray links gain count=screen`, screenHrefs[0]);
  await fullPageShot(page, `${vp.name}-category-choices`);

  await page.reload();
  await settle(page);
  check(
    await eventually(() => radio("On the screen").isChecked()),
    `${label}: counting on the screen persists across a reload`
  );
  check(
    await eventually(async () => (await prayHrefs()).every((h) => h.includes("count=screen"))),
    `${label}: Pray links still carry count=screen after the reload`
  );
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

async function checkPrayerScreen(browser, vp) {
  const label = `${vp.name} prayer, counting on the screen`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const setPath = await firstSetPath(page);
  const url = `${BASE_URL}${setPath}?count=screen`;
  await page.goto(url);
  await settle(page);
  check((await page.getByRole("heading", { level: 1 }).count()) >= 1, `${label}: has an h1`);
  check((await page.getByRole("button", { name: "Next bead" }).count()) === 1, `${label}: shows the Next bead button`);
  await noHorizontalScroll(page, label);

  // Each way of moving on changes what the live region says.
  let seen = await beadStatus(page);
  const moved = async (how) => {
    const now = await eventually(async () => ((await beadStatus(page)) !== seen ? beadStatus(page) : false));
    check(Boolean(now), `${label}: ${how} advances the bead`, `still "${seen}"`);
    if (now) seen = now;
  };

  await page.keyboard.press(" ");
  await moved("Space");
  await page.keyboard.press("ArrowDown");
  await moved("ArrowDown");
  await page.getByRole("button", { name: "Next bead" }).click();
  await moved("the Next bead button");
  await page.keyboard.press("ArrowLeft");
  await eventually(async () => (await beadStatus(page)) !== seen);
  seen = await beadStatus(page);
  await fullPageShot(page, `${vp.name}-pray-screen`);

  // The settings pane, by keyboard.
  const toggle = page.getByRole("button", { name: "How to pray" });
  const expanded = async () => (await toggle.getAttribute("aria-expanded")) === "true";
  await toggle.focus();
  await page.keyboard.press("Enter");
  check(await eventually(expanded), `${label}: Enter on How to pray opens the settings`);
  await noHorizontalScroll(page, `${label} with the settings open`);
  await fullPageShot(page, `${vp.name}-pray-settings`);
  await page.keyboard.press("Enter");
  check(await eventually(async () => !(await expanded())), `${label}: Enter on How to pray closes the settings`);
  await page.keyboard.press("Enter");
  await eventually(expanded);
  await page.keyboard.press("Escape");
  check(await eventually(async () => !(await expanded())), `${label}: Escape closes the settings`);

  // Text size is kept in this browser.
  if (!(await expanded())) await toggle.click();
  const scale = () => page.evaluate(() => document.documentElement.style.getPropertyValue("--prayer-text-scale"));
  const before = await scale();
  await page.getByRole("button", { name: "Larger text" }).focus();
  await page.keyboard.press("Enter");
  const after = await scale();
  check(after !== before && after !== "", `${label}: Larger text changes the text size`, `${before} -> ${after}`);
  await page.reload();
  await settle(page);
  check(
    await eventually(async () => (await scale()) === after),
    `${label}: the text size persists across a reload`,
    `wanted ${after}, got ${await scale()}`
  );
  await noHorizontalScroll(page, `${label} after the larger text`);

  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

async function checkScriptural(browser, vp) {
  const label = `${vp.name} scriptural form`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(`${BASE_URL}/mysteries/sorrowful/pray?form=scriptural&count=screen`);
  await settle(page);
  check((await page.getByRole("heading", { level: 1 }).count()) >= 1, `${label}: has an h1`);
  await noHorizontalScroll(page, label);

  // Walk to the first Hail Mary: its screen must open with a verse.
  let found = null;
  for (let i = 0; i < 30 && !found; i += 1) {
    const status = await beadStatus(page);
    // "Hail Mary · 1 of 10": the ones before the first decade carry no verse.
    if (/hail mary\s*·\s*\d+ of \d+/i.test(status)) {
      found = status;
      break;
    }
    const seen = status;
    await page.keyboard.press(" ");
    await eventually(async () => (await beadStatus(page)) !== seen);
  }
  check(Boolean(found), `${label}: reaches a Hail Mary bead`);
  if (found) {
    const verses = await page.locator("blockquote").count();
    const verseText = verses ? (await page.locator("blockquote").first().innerText()).trim() : "";
    check(verseText.length > 0, `${label}: a verse shows before the Hail Mary`);
    const order = await page.evaluate(() => {
      const verse = document.querySelector("blockquote");
      const hail = [...document.querySelectorAll("p")].find((p) => /blessed art thou|full of grace/i.test(p.innerText));
      if (!verse || !hail) return null;
      return Boolean(verse.compareDocumentPosition(hail) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    check(order === true, `${label}: the verse comes before the prayer`, String(order));
    await fullPageShot(page, `${vp.name}-pray-scriptural`);
  }
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

async function checkSetlessAndUnknown(browser, vp) {
  const label = `${vp.name} set-less prayer`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const holy = await page.goto(`${BASE_URL}/mysteries/joyful/pray?form=holy`);
  await settle(page);
  check(holy && holy.status() === 200, `${label}: the holy form loads`, `got ${holy && holy.status()}`);
  check((await page.getByRole("heading", { level: 1 }).count()) >= 1, `${label}: the holy form has an h1`);
  await noHorizontalScroll(page, `${label} (holy)`);
  await fullPageShot(page, `${vp.name}-pray-holy`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  for (const unknown of ["/mysteries/not-a-category/pray", "/mysteries/not-a-category", "/meditation-sets/99999999/pray"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// Records a completion in whatever database the server is using: run it
// against a copy, never against production.
async function checkCompletion(browser, vp) {
  const label = `${vp.name} completion`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const setPath = await firstSetPath(page);
  await page.goto(`${BASE_URL}${setPath}?mystery=closing`);
  await settle(page);
  const complete = page.getByRole("button", { name: /complete/i });
  check((await complete.count()) === 1, `${label}: the closing page offers Complete`);
  await noHorizontalScroll(page, `${label} (closing)`);
  await complete.click();
  const offered = page.getByRole("heading", { name: /offered/i });
  check(await eventually(async () => (await offered.count()) > 0), `${label}: the completion screen shows`);
  check(
    (await page.getByRole("link", { name: /back to the/i }).count()) > 0,
    `${label}: the completion screen links back to the mysteries`
  );
  await noHorizontalScroll(page, `${label} (done)`);
  await fullPageShot(page, `${vp.name}-pray-complete`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch({ channel: "chrome" });

  for (const vp of VIEWPORTS) {
    const errors = [];
    const { context, page } = await freshPage(browser, vp, errors);

    for (const spec of PAGES) await checkPage(page, errors, vp, spec);
    await checkPrayFlow(page, errors, vp);
    await checkRedirects(page, vp);
    await context.close();

    await checkCategoryChoices(browser, vp);
    await checkPrayerScreen(browser, vp);
    await checkScriptural(browser, vp);
    await checkSetlessAndUnknown(browser, vp);
  }

  // Once only: it writes a completion row to the server's database.
  await checkCompletion(browser, VIEWPORTS[1]);

  await browser.close();

  console.log(`\n${checks - failures.length}/${checks} checks passed; screenshots in ${OUT_DIR}`);
  if (failures.length) {
    console.log("\nFailures:");
    for (const f of failures) console.log(`  - ${f}`);
    process.exit(1);
  }
})().catch((err) => {
  console.error(err);
  process.exit(2);
});
