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

  const prayLink = page.getByRole("link", { name: /pray/i }).first();
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

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch({ channel: "chrome" });

  for (const vp of VIEWPORTS) {
    const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await context.newPage();

    const errors = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(`${msg.text()} @ ${msg.location().url}`);
    });
    page.on("pageerror", (err) => errors.push(`pageerror: ${err.message}`));

    for (const spec of PAGES) await checkPage(page, errors, vp, spec);
    await checkPrayFlow(page, errors, vp);
    await checkRedirects(page, vp);

    await context.close();
  }

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
