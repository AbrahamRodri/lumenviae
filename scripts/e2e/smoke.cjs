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

async function connected(page) {
  return page.evaluate(() => {
    const main = document.querySelector("[data-phx-main]");
    return Boolean(main && main.classList.contains("phx-connected"));
  });
}

// What the prayer page's hooks keep in this browser, checked in a fresh
// context so nothing saved by an earlier run is in the way: the text size a
// first visit starts at, and values damaged in localStorage, which must be
// passed over rather than break the page.
async function checkHooks(page, errors, vp) {
  const label = `${vp.name} prayer hooks`;
  console.log(label);
  errors.length = 0;
  const pray = `${BASE_URL}/mysteries/joyful/pray`;

  await page.goto(pray);
  await settle(page);
  const scale = await page.evaluate(() =>
    getComputedStyle(document.documentElement).getPropertyValue("--prayer-text-scale").trim()
  );
  check(scale === "1", `${label}: a first visit reads at the normal text size`, `scale ${scale}`);

  const key = await page.evaluate(() => document.querySelector("[phx-hook=PrayerMemory]").dataset.key);
  await page.evaluate((key) => {
    localStorage.setItem(`lv:pray:${key}`, JSON.stringify({ mystery: { a: 1 }, step: [1], at: Date.now() }));
    // Yesterday, with the count saved as a string: carried on, it would
    // read "71 days".
    const date = new Date();
    date.setDate(date.getDate() - 1);
    const pad = (n) => String(n).padStart(2, "0");
    const last = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    localStorage.setItem("lv:pray:streak", JSON.stringify({ last, days: "7" }));
  }, key);
  await page.reload();
  await settle(page);
  check(await connected(page), `${label}: a damaged saved place leaves the page connected`);

  await page.goto(`${pray}?mystery=closing`);
  await settle(page);
  await page.getByRole("button", { name: /Complete/ }).click();
  await page.waitForTimeout(500);
  const streak = await page.evaluate(() => document.querySelector("[data-streak]").textContent.trim());
  check(streak === "1 day so far", `${label}: a damaged streak starts again from today`, `"${streak}"`);

  await page.goto(`${pray}?aloud=true`);
  await settle(page);
  await page.getByRole("button", { name: /Praying aloud/ }).click();
  await page.waitForTimeout(500);
  const playback = await page.evaluate(() =>
    "mediaSession" in navigator ? navigator.mediaSession.playbackState : "none"
  );
  check(playback === "none", `${label}: turning the voice off lets go of the media controls`, playback);

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

    await checkHooks(page, errors, vp);
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
