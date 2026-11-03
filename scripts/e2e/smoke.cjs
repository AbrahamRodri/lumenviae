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

// The server's date, near enough for the Hours pages: any served date works.
const TODAY = new Date().toISOString().slice(0, 10);

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
  { path: "/app", slug: "app" },
  { path: "/prayers", slug: "prayers" },
  { path: "/prayers?q=memorare", slug: "prayers-search" },
  { path: "/prayers/topics/our_lady", slug: "prayers-topic" },
  { path: "/prayers/memorare", slug: "prayer" },
  { path: "/prayers/litany_loreto?lang=both", slug: "prayer-both" },
  { path: "/prayers/orders/morning", slug: "prayer-order" },
  { path: "/prayers/orders/morning/pray?step=3&lang=both", slug: "prayer-order-pray" },
  { path: "/true-devotion", slug: "true-devotion" },
  { path: "/true-devotion/motives", slug: "true-devotion-chapter" },
  { path: "/spiritual-reading", slug: "spiritual-reading" },
  { path: "/spiritual-reading/practice-of-the-presence-of-god", slug: "spiritual-reading-book" },
  { path: "/hours", slug: "hours" },
  { path: `/hours/${TODAY}/vesperae?lang=both`, slug: "hour-both" },
  { path: `/hours/calendar/${TODAY.slice(0, 4)}/${Number(TODAY.slice(5, 7))}`, slug: "hours-calendar" },
  { path: "/missal", slug: "missal" },
  { path: `/missal/${TODAY}?lang=both`, slug: "missal-both" },
  { path: "/missal/order-of-mass", slug: "missal-ordo" },
  { path: `/missal/calendar/${TODAY.slice(0, 4)}/${Number(TODAY.slice(5, 7))}`, slug: "missal-calendar" },
  { path: "/chant", slug: "chant" },
  { path: "/chant?q=salve", slug: "chant-search" },
  { path: "/chant/sections/mass", slug: "chant-section" },
  { path: "/chant/salve_regina_simple", slug: "chant-page" },
  { path: "/chant/sets", slug: "chant-sets" },
  { path: "/chant/sets/sung_rosary", slug: "chant-set" },
  { path: "/consecration", slug: "consecration" },
  { path: "/consecration?step=choose", slug: "consecration-choose" },
  { path: "/consecration/days/15", slug: "consecration-day" },
  { path: "/consecration/days/15?step=1&lang=both", slug: "consecration-flow" },
  { path: "/consecration/act", slug: "consecration-act" },
  { path: "/explore", slug: "explore" },
  { path: "/explore?q=salve", slug: "explore-search" },
];

const APP_STORE = "https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749";

// /true-devotion left this list when the book came to the site; it is
// checked in checkTrueDevotion instead.
const RETIRED = ["/dashboard", "/rosary-methods", "/saint-carlo", "/feedback"];

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
  await page.getByRole("button", { name: "Hear the prayers", pressed: true }).click();
  await page.waitForTimeout(500);
  const playback = await page.evaluate(() =>
    "mediaSession" in navigator ? navigator.mediaSession.playbackState : "none"
  );
  check(playback === "none", `${label}: turning the voice off lets go of the media controls`, playback);

  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
}

// The iPhone app's page: every download link goes to the App Store listing,
// and each screenshot has loaded.
async function checkAppPage(page, vp) {
  const label = `${vp.name} /app`;
  console.log(`${label} (downloads)`);
  await page.goto(`${BASE_URL}/app`);
  await settle(page);

  const hrefs = await page.locator('a[href^="https://apps.apple.com"]').evaluateAll((links) =>
    links.map((a) => a.getAttribute("href"))
  );
  check(hrefs.length >= 2, `${label}: has App Store links`, `found ${hrefs.length}`);
  check(hrefs.every((href) => href === APP_STORE), `${label}: every App Store link is the listing`, hrefs.join(" "));

  await page.evaluate(async () => {
    for (const img of document.images) img.loading = "eager";
    await Promise.all([...document.images].map((img) => (img.complete ? null : img.decode().catch(() => {}))));
  });
  const broken = await page.evaluate(() =>
    [...document.querySelectorAll("main img")].filter((img) => !img.naturalWidth).map((img) => img.currentSrc || img.src)
  );
  check(broken.length === 0, `${label}: every screenshot loads`, broken.join(" "));
}

// The Prayer Book: typing in the search puts it in the link and finds the
// Memorare; its page offers the languages and Both rides in the link; an
// order of prayer's Pray and Next step through it in the link; an unknown
// prayer, topic or order is a 404.
async function checkPrayers(browser, vp) {
  const label = `${vp.name} prayers`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/prayers");
  await settle(page);
  await page.getByRole("searchbox", { name: /search prayers/i }).fill("memorare");
  const searched = await eventually(() => new URL(page.url()).searchParams.get("q") === "memorare");
  check(searched, `${label}: the search rides in the link`, page.url());
  const found = await eventually(async () => (await page.locator('a[href="/prayers/memorare"]').count()) > 0);
  check(found, `${label}: the search finds the Memorare`);

  await page.locator('a[href="/prayers/memorare"]').first().click();
  await eventually(() => new URL(page.url()).pathname === "/prayers/memorare");
  await page.getByRole("navigation", { name: "Language" }).getByRole("link", { name: "Both" }).click();
  const both = await eventually(() => new URL(page.url()).searchParams.get("lang") === "both");
  check(both, `${label}: Both rides in the link`, page.url());
  await noHorizontalScroll(page, `${label} (both)`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  // An order of prayer: Pray opens its first prayer, and Next turns to
  // the second in the link.
  await page.goto(BASE_URL + "/prayers/orders/morning");
  await settle(page);
  // The dev server's Tidewave toolbar sits over the foot at a phone's
  // width; it is not on the site.
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=order-pray]").click();
  const praying = await eventually(() => new URL(page.url()).pathname === "/prayers/orders/morning/pray");
  check(praying, `${label}: Pray opens the order's first prayer`, page.url());
  await settle(page);
  await page.locator("[data-role=next]").click();
  const stepped = await eventually(() => new URL(page.url()).searchParams.get("step") === "2");
  check(stepped, `${label}: Next turns to the second prayer in the link`, page.url());
  const heading = await eventually(async () => (await page.locator("h1").textContent()).includes("Morning Offering"));
  check(heading, `${label}: the second prayer is on the page`);
  await noHorizontalScroll(page, `${label} (order)`);
  check(errors.length === 0, `${label}: no console errors after praying`, errors.join(" | "));

  for (const unknown of ["/prayers/not-a-prayer", "/prayers/topics/nowhere", "/prayers/orders/nowhere"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// Today's Prayer on Home: the Consecration's row, the hour's order and the
// Hours of Prayer, each waiting for the browser (its plan, its clock); each
// row's link opens its page, and a plan kept in this browser turns the
// Consecration's row to today's day.
async function checkTodaysPrayer(browser, vp) {
  const label = `${vp.name} today's prayer`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const row = (id) => page.locator(`#todays-prayer [data-role=row-${id}]`);
  const openHome = async () => {
    await page.goto(BASE_URL + "/");
    await settle(page);
    await eventually(async () => (await row("office").count()) > 0);
    await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  };
  const follows = async (id, pattern, name) => {
    await openHome();
    await row(id).click();
    const ok = await eventually(() => pattern.test(new URL(page.url()).pathname));
    check(ok, `${label}: ${name} opens its page`, page.url());
    await settle(page);
  };

  await openHome();
  check(
    (await page.getByRole("heading", { name: "Today's Prayer" }).count()) === 1,
    `${label}: Home shows Today's Prayer`
  );
  check((await page.locator("#todays-prayer [data-role=waiting]").count()) === 0, `${label}: every row has spoken`);
  check((await row("consecration").getAttribute("href")) === "/consecration", `${label}: no plan invites one`);
  check((await row("consecration").innerText()).includes("Give yourself to Jesus through Mary"), `${label}: the Consecration's line`);
  check(/^\/prayers\/orders\/(morning|angelus|night)$/.test(await row("hour_order").getAttribute("href")), `${label}: the hour's order`);
  check((await row("office").innerText()).toUpperCase().includes("NOW"), `${label}: the Hours of Prayer's hour now`);
  check((await row("mass").getAttribute("href")) === "/missal", `${label}: Today's Mass opens the Missal`);
  await noHorizontalScroll(page, label);

  await follows("hour_order", /^\/prayers\/orders\/(morning|angelus|night)$/, "the hour's order");
  await follows("office", /^\/hours$/, "the Hours of Prayer");
  await follows("mass", /^\/missal$/, "Today's Mass");
  await follows("consecration", /^\/consecration$/, "the Consecration");

  await page.evaluate(() => {
    const d = new Date();
    d.setDate(d.getDate() - 4);
    const p = (n) => String(n).padStart(2, "0");
    const start = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
    localStorage.setItem("lv:consecration:plan", JSON.stringify({ start, feast_id: null, started_at: new Date().toISOString(), completed_at: null }));
    localStorage.setItem("lv:consecration:done", JSON.stringify([5]));
  });
  await openHome();
  check(
    await eventually(async () => (await row("consecration").getAttribute("href")) === "/consecration/days/5"),
    `${label}: a plan under way names today's day`
  );
  check((await row("consecration").getAttribute("data-prayed")) === "true", `${label}: the day prayed is marked`);
  await follows("consecration", /^\/consecration\/days\/5$/, "the Consecration's day");
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

// The Consecration: the chooser's Begin keeps a plan in this browser and
// the page turns to the waiting page or today's day; Start at any day at
// Day 15 opens Day 15; Pray and Next step through the day in the link;
// Amen at the last step comes back to the day, marked prayed; the Act's
// page shows, and a day that is not one is a 404.
async function checkConsecration(browser, vp) {
  const label = `${vp.name} consecration`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  // The presses are the ConsecrationPlan hook's, so wait for it to have
  // spoken (the stage shows only then).
  const known = () => eventually(async () => (await page.locator("[data-role=stage][data-known=true]").count()) > 0);

  await page.goto(BASE_URL + "/consecration?step=choose");
  await settle(page);
  await known();
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=begin]").click();
  const begun = await eventually(
    async () => (await page.locator("[data-role=scheduled]").count()) > 0 || /\/consecration\/days\/1$/.test(page.url())
  );
  check(begun, `${label}: Begin keeps the feast and turns the page`, page.url());

  await page.goto(BASE_URL + "/consecration");
  await settle(page);
  await known();
  if ((await page.locator("[data-role=another-feast]").count()) > 0) {
    await page.locator("[data-role=another-feast]").click();
  }
  await eventually(async () => (await page.locator("[data-role=any-start]").count()) > 0);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=any-start]").click();
  await page.locator("[data-role=any-day]").selectOption("15");
  await eventually(async () => (await page.locator("[data-role=any-begin]").textContent()).includes("Day 15"));
  await page.locator("[data-role=any-begin]").click();
  const day = await eventually(() => new URL(page.url()).pathname === "/consecration/days/15");
  check(day, `${label}: Start at any day opens today's day`, page.url());
  await settle(page);
  check(
    await eventually(async () => (await page.locator("[data-role=pray]").textContent()).includes("Begin today")),
    `${label}: the day is today's`
  );

  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=pray]").click();
  check(await eventually(() => new URL(page.url()).searchParams.get("step") === "1"), `${label}: Pray opens the first prayer`, page.url());
  await settle(page);
  await page.locator("[data-role=next]").click();
  check(await eventually(() => new URL(page.url()).searchParams.get("step") === "2"), `${label}: Next steps in the link`, page.url());
  await noHorizontalScroll(page, `${label} (step)`);

  await page.goto(BASE_URL + "/consecration/days/15?step=99");
  await settle(page);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=amen]").click();
  check(await eventually(() => new URL(page.url()).pathname === "/consecration/days/15" && !page.url().includes("step")), `${label}: Amen returns to the day`, page.url());
  await settle(page);
  check(
    await eventually(async () => (await page.locator("[data-role=pray]").textContent()).includes("Pray it again")),
    `${label}: the day is kept as prayed`
  );

  // A day ahead is open to read, but its Amen keeps nothing: on Day 1,
  // Consecration Day's Amen neither marks it prayed nor completes the plan.
  await page.evaluate(() => {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const start = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
    localStorage.setItem("lv:consecration:plan", JSON.stringify({ start, feast_id: null, started_at: now.toISOString(), completed_at: null }));
    localStorage.removeItem("lv:consecration:done");
  });
  await page.goto(BASE_URL + "/consecration/days/34?step=99");
  await settle(page);
  check(
    await eventually(async () => (await page.locator("[data-role=amen]").getAttribute("href")) === "/consecration/days/34"),
    `${label}: a day ahead's Amen returns to it`
  );
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
  await page.locator("[data-role=amen]").click();
  await eventually(() => new URL(page.url()).pathname === "/consecration/days/34" && !page.url().includes("step"));
  const kept = await page.evaluate(() => ({
    plan: JSON.parse(localStorage.getItem("lv:consecration:plan") || "null"),
    done: JSON.parse(localStorage.getItem("lv:consecration:done") || "[]"),
  }));
  check(kept.plan && kept.plan.completed_at == null && kept.done.length === 0, `${label}: a day ahead's Amen keeps nothing`, JSON.stringify(kept));
  await page.goto(BASE_URL + "/consecration");
  check(await eventually(() => new URL(page.url()).pathname === "/consecration/days/1"), `${label}: the Consecration still opens Day 1`, page.url());

  await page.goto(BASE_URL + "/consecration/act");
  await settle(page);
  check((await page.locator("h1").textContent()).includes("I am all yours"), `${label}: the Act's page`);
  await noHorizontalScroll(page, `${label} (act)`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  for (const unknown of ["/consecration/days/35", "/consecration/days/x"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// Hours of Prayer: Pray on /hours opens the hour now, Both rides in the
// link, and the text arrives or the page says it could not be reached. The
// engine may be unreachable from a dev machine, so either answer passes and
// the log says which it was. An unknown hour and a bad date are 404s.
async function checkHours(browser, vp) {
  const label = `${vp.name} hours`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/hours");
  await settle(page);
  const pray = page.getByRole("link", { name: /^Pray / });
  const href = await pray.getAttribute("href");
  check(/^\/hours\/\d{4}-\d{2}-\d{2}\/[a-z]+$/.test(href || ""), `${label}: Pray opens the hour now`, href);
  const feast = await eventually(async () => {
    const text = await page.locator("[data-role=feast]").innerText();
    return !/Finding the day/.test(text) && text;
  }, 20000);
  console.log(`        the day's feast: ${feast ? feast.replace(/\s+/g, " ").trim() : "still loading"}`);

  await pray.click();
  await eventually(() => new URL(page.url()).pathname === href);
  await settle(page);
  await page.getByRole("navigation", { name: "Language" }).getByRole("link", { name: "Both" }).click();
  const both = await eventually(() => new URL(page.url()).searchParams.get("lang") === "both");
  check(both, `${label}: Both rides in the link`, page.url());

  const outcome = await eventually(async () => {
    if ((await page.locator("[data-role=office-text]").count()) > 0) return "text";
    if ((await page.locator("[data-role=hour-failed]").count()) > 0) return "unreachable";
    return false;
  }, 30000);
  check(Boolean(outcome), `${label}: the hour arrives or says it could not be reached`);
  console.log(`        the hour: ${outcome === "text" ? "text from the engine" : outcome || "neither"}`);
  await noHorizontalScroll(page, `${label} (both)`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  for (const unknown of ["/hours/not-a-date", `/hours/${TODAY}/midnight`, "/hours/calendar/2026/13"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// The Daily Missal: today's Mass arrives or the page says Missale Meum
// could not be reached (the server fetches it, and it may not answer a dev
// machine, so either passes and the log says which); Both rides in the
// link and across the day's arrows; the day's foot opens the Order of
// Mass; the date pill opens the month; a bad date and month 13 are 404s.
async function checkMissal(browser, vp) {
  const label = `${vp.name} missal`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/missal");
  await settle(page);
  const pill = page.locator("[data-role=date-pill]");
  check(await eventually(async () => (await pill.count()) > 0), `${label}: the date pill once the clock is known`);
  const outcome = await eventually(async () => {
    if ((await page.locator("[data-role=missal-text]").count()) > 0) return "text";
    if ((await page.locator("[data-role=mass-failed]").count()) > 0) return "unreachable";
    if ((await page.locator("[data-role=mass-none]").count()) > 0) return "none";
    return false;
  }, 30000);
  check(Boolean(outcome), `${label}: the Mass arrives or says it could not be reached`);
  const feast = outcome === "text" ? (await page.locator("[data-role=feast]").innerText()).trim() : "";
  console.log(`        today's Mass: ${outcome === "text" ? `text from Missale Meum (${feast})` : outcome || "neither"}`);

  // With the Ordinary: the Whole Mass by default, as the app reads it;
  // Today's texts only takes the Ordinary out and is remembered by this
  // browser; Sung adds the incense. The Order of Mass is fetched beside
  // the day and may not answer either, so the Ordinary's parts are
  // checked only when they came.
  const pressed = (value) => page.locator(`[data-role=contents] [data-contents=${value}][aria-pressed=true]`);
  check((await pressed("whole").count()) === 1, `${label}: Whole Mass is the default`);
  check((await page.locator("[data-role=sung] [data-sung=false][aria-pressed=true]").count()) === 1, `${label}: the Mass is spoken by default`);
  const kyrie = page.locator("[data-rail-link]", { hasText: "Lord, Have Mercy" });
  const woven = outcome === "text" && (await eventually(async () => (await kyrie.count()) > 0, 10000));
  console.log(`        with the Ordinary: ${woven ? "woven in" : "not shown (no text or no Order of Mass)"}`);
  await page.locator("[data-role=contents] [data-contents=propers]").click();
  check(await eventually(async () => (await pressed("propers").count()) === 1), `${label}: Today's texts only is chosen`);
  check((await page.locator("[data-role=sung]").count()) === 0, `${label}: Spoken or Sung only with the Whole Mass`);
  if (woven) check(await eventually(async () => (await kyrie.count()) === 0), `${label}: Today's texts only leaves the Ordinary out`);
  await page.reload();
  await settle(page);
  check(await eventually(async () => (await pressed("propers").count()) === 1), `${label}: the choice is remembered by this browser`);
  await page.locator("[data-role=contents] [data-contents=whole]").click();
  check(await eventually(async () => (await pressed("whole").count()) === 1), `${label}: Whole Mass again`);
  await page.locator("[data-role=sung] [data-sung=true]").click();
  check(await eventually(async () => (await page.locator("[data-role=sung] [data-sung=true][aria-pressed=true]").count()) === 1), `${label}: Sung is chosen`);
  if (woven) {
    const incense = page.locator("[data-rail-link]", { hasText: "Incensing" });
    check(await eventually(async () => (await incense.count()) === 1, 10000), `${label}: a sung Mass adds the incense`);
  }
  await noHorizontalScroll(page, `${label} (with the Ordinary)`);
  await page.locator("[data-role=sung] [data-sung=false]").click();

  await page.getByRole("navigation", { name: "Language" }).getByRole("link", { name: "Both" }).click();
  check(
    await eventually(() => new URL(page.url()).searchParams.get("lang") === "both"),
    `${label}: Both rides in the link`,
    page.url()
  );
  await page.locator("[data-role=next-day]").click();
  check(
    await eventually(() => /^\/missal\/\d{4}-\d{2}-\d{2}$/.test(new URL(page.url()).pathname) && new URL(page.url()).searchParams.get("lang") === "both"),
    `${label}: the next day keeps Both`,
    page.url()
  );
  await settle(page);
  await noHorizontalScroll(page, `${label} (next day, both)`);

  const ordo = page.locator("[data-role=ordo-link]");
  if (await eventually(async () => (await ordo.count()) > 0, 20000)) {
    await ordo.click();
    check(await eventually(() => new URL(page.url()).pathname === "/missal/order-of-mass"), `${label}: the day's foot opens the Order of Mass`, page.url());
  } else {
    await page.goto(BASE_URL + "/missal/order-of-mass?lang=both");
  }
  await settle(page);
  const ordoOutcome = await eventually(async () => {
    if ((await page.locator("[data-role=ordo-text]").count()) > 0) return "text";
    if ((await page.locator("[data-role=ordo-failed]").count()) > 0) return "unreachable";
    return false;
  }, 30000);
  check(Boolean(ordoOutcome), `${label}: the Order of Mass arrives or says it could not be reached`);
  console.log(`        the Order of Mass: ${ordoOutcome || "neither"}`);
  await noHorizontalScroll(page, `${label} (order of mass)`);

  await page.goto(BASE_URL + "/missal");
  await settle(page);
  await eventually(async () => (await pill.count()) > 0);
  await pill.click();
  check(
    await eventually(() => /^\/missal\/calendar\/\d{4}\/\d{1,2}$/.test(new URL(page.url()).pathname)),
    `${label}: the date pill opens the month`,
    page.url()
  );
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  for (const unknown of ["/missal/not-a-date", "/missal/calendar/2026/13"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// The Chant Library: the search rides in the link and finds the Salve
// Regina; a section's shelf offers Play all and its chants; a chant's
// page carries the recording and its lines, and pressing play lights a
// line once the recording reaches it (the chant is fetched from the
// site's bucket, so this needs a network); an unknown section or chant
// is a 404.
async function checkChant(browser, vp) {
  const label = `${vp.name} chant`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/chant");
  await settle(page);
  await page.getByRole("searchbox", { name: /search chants/i }).fill("salve regina");
  const searched = await eventually(() => new URL(page.url()).searchParams.get("q") === "salve regina");
  check(searched, `${label}: the search rides in the link`, page.url());
  const found = await eventually(async () => (await page.locator('[data-role=results] a[href="/chant/salve_regina_simple"]').count()) > 0);
  check(found, `${label}: the search finds the Salve Regina`);

  await page.goto(BASE_URL + "/chant/sections/mass");
  await settle(page);
  check((await page.locator("[data-role=play-all]").count()) === 1, `${label}: the shelf offers Play all`);
  check((await page.locator("[data-role=chant-row]").count()) >= 8, `${label}: the shelf lists its chants`);

  await page.goto(BASE_URL + "/chant/salve_regina_simple");
  await settle(page);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root], #live-debugger { display: none !important; }" });
  const src = await page.locator("[data-role=player]").getAttribute("data-src");
  check(/^https:\/\/s3\.us-east-2\.amazonaws\.com\/lumenviae-images\/chants\/audio\//.test(src || ""), `${label}: the page carries the recording`, src);
  check((await page.locator("[data-role=line]").count()) > 1, `${label}: the page lists the lines`);
  await page.locator("[data-role=play]").click();
  const lit = await eventually(async () => {
    const line = await page.locator("[data-role=line][aria-current]").getAttribute("data-line").catch(() => null);
    return line !== null && Number(line) >= 1;
  }, 30000);
  check(lit, `${label}: playing lights the line being sung`);
  await page.locator("[data-role=play]").click();
  await page.getByRole("navigation", { name: "Words" }).getByRole("link", { name: "English" }).click();
  const english = await eventually(() => new URL(page.url()).searchParams.get("words") === "english");
  check(english, `${label}: the Words ride in the link`, page.url());
  await noHorizontalScroll(page, `${label} (playing)`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  // The full score: The Sheet Music opens it over the page in the link,
  // every page drawn from the site's copy of the bucket's file, a
  // double-click and the + button bring it closer within its own frame,
  // and Escape goes back to the page.
  await page.locator("[data-role=score-open]").click();
  const opened = await eventually(() => new URL(page.url()).searchParams.get("score") === "full");
  check(opened, `${label}: the full score rides in the link`, page.url());
  check(await page.getByRole("dialog", { name: /salve regina/i }).isVisible(), `${label}: the full score opens over the page`);
  const parts = await page.locator("[data-role=score-drawing]").count();
  const drawn = await eventually(
    async () => (await page.locator("[data-role=score-drawing][data-drawn=drawn] svg path").count()) > 100 &&
      (await page.locator("[data-role=score-drawing][data-drawn=drawn]").count()) === parts,
    20000,
  );
  check(parts >= 1 && drawn, `${label}: every page of the score is drawn`, `${parts} pages`);
  const glass = page.locator("[data-role=score-glass]");
  const width = () => page.locator(".chant-score__sheet").evaluate((el) => el.getBoundingClientRect().width);
  const before = await width();
  await glass.dblclick({ position: { x: 60, y: 60 } });
  const doubled = await eventually(async () => Math.abs((await width()) - 2 * before) < 2);
  check(doubled, `${label}: a double-click brings the score to twice the width`, `${before} -> ${await width()}`);
  await page.getByRole("button", { name: "Zoom in" }).click();
  check((await width()) > 2.5 * before, `${label}: Zoom in brings it closer still`);
  check(await glass.evaluate((g) => g.scrollWidth > g.clientWidth), `${label}: the zoomed score scrolls in its own frame`);
  await noHorizontalScroll(page, `${label} (full score zoomed)`);
  await page.keyboard.press("Escape");
  const closed = await eventually(async () => (await page.locator("[data-role=score]").count()) === 0 && !new URL(page.url()).searchParams.has("score"));
  check(closed, `${label}: Escape closes the full score back to the page`, page.url());
  check(errors.length === 0, `${label}: no console errors on the full score`, errors.join(" | "));

  // Sets of Chants lists the six; a set's Play all sings its first chant
  // and lights its row.
  await page.goto(BASE_URL + "/chant/sets");
  await settle(page);
  check((await page.locator("[data-role=wide-set-card]").count()) === 6, `${label}: Sets of Chants lists six sets`);
  await page.goto(BASE_URL + "/chant/sets/benediction");
  await settle(page);
  check((await page.locator("[data-role=rubric]").count()) >= 1, `${label}: the set's notes in red`);
  await page.locator("[data-role=play-all]").click();
  const singing = await eventually(async () => {
    const lit = await page.locator('[data-role=set-row][data-origin="0"][data-sounding]').count();
    const playing = await page.locator("audio#site-chant-audio").evaluate((a) => !a.paused && a.currentTime > 0);
    return lit === 1 && playing;
  }, 30000);
  check(singing, `${label}: Play all sings the set's first chant`);
  check((await page.locator("[data-play-set-word]").textContent()).trim() === "Pause", `${label}: Play all turns to Pause`);
  await page.locator("[data-role=play-all]").click();
  await noHorizontalScroll(page, `${label} (set)`);
  check(errors.length === 0, `${label}: no console errors on the sets`, errors.join(" | "));

  for (const unknown of ["/chant/nowhere", "/chant/sections/nowhere", "/chant/sets/nowhere"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// The chant mini player (the app's ChantMiniPlayer): a chant played on a
// shelf goes on singing across a live navigation, with the mini player at
// the foot of the next page; its disc pauses and plays; its names open the
// chant's page, where it stands aside; after a full page load it comes
// back paused where it stood and its disc goes on; close puts it away.
// The recording comes from the site's bucket, so this needs a network.
async function checkChantMiniPlayer(browser, vp) {
  const label = `${vp.name} chant mini player`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);
  const mini = page.locator("#chant-mini");
  const sounding = () =>
    page.locator("audio#site-chant-audio").evaluate((a) => (!a.paused && a.currentTime > 0 ? a.currentTime : 0));

  await page.goto(BASE_URL + "/chant/sections/mass");
  await settle(page);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root], #live-debugger { display: none !important; }" });
  check(!(await mini.isVisible()), `${label}: hidden until a chant is in hand`);
  const disc = page.locator("[data-role=chant-row] [data-play]").first();
  const id = await disc.getAttribute("data-play");
  const latin = JSON.parse(await disc.getAttribute("data-facts")).latin;
  await disc.click();
  check(await eventually(sounding, 30000), `${label}: a disc on a shelf sings its chant`);
  check(await eventually(() => mini.isVisible()), `${label}: the mini player stands at the shelf's foot`);

  // A live navigation, as every link between the public pages is
  await page.evaluate(() => (window.__sameDocument = true));
  await page.locator('#site-footer a[href="/mysteries"]').click();
  await page.waitForURL(/\/mysteries$/);
  await settle(page);
  check(await page.evaluate(() => window.__sameDocument === true), `${label}: the footer's link navigates live`);
  const t1 = await sounding();
  await page.waitForTimeout(1200);
  const t2 = await sounding();
  check(t1 > 0 && t2 > t1, `${label}: the chant sings on after the navigation`, `${t1} -> ${t2}`);
  check(await mini.isVisible(), `${label}: the mini player stands at the next page's foot`);
  check((await mini.locator("[data-role=mini-title]").textContent()).trim() === latin, `${label}: it names the chant`, latin);
  check(/ of \d+:\d\d$/.test((await mini.locator("[data-role=mini-subtitle]").textContent()).trim()), `${label}: it says where the chant stands`);
  check(await page.evaluate(() => document.documentElement.hasAttribute("data-chant-mini")), `${label}: the page keeps room at its foot`);
  await noHorizontalScroll(page, `${label} (showing)`);
  await page.screenshot({ path: path.join(OUT_DIR, `${vp.name}-chant-mini.png`) });

  const play = mini.locator("[data-role=mini-play]");
  check((await play.getAttribute("aria-pressed")) === "true", `${label}: its disc shows pause while it sings`);
  await play.click();
  check(await eventually(async () => (await sounding()) === 0), `${label}: its disc pauses the chant`);
  check(await eventually(async () => (await play.getAttribute("aria-label")).startsWith("Play ")), `${label}: the paused disc is labelled Play`);
  await play.click();
  check(await eventually(sounding, 10000), `${label}: its disc sings it again`);

  await mini.locator("[data-role=mini-open]").click();
  await page.waitForURL(new RegExp(`/chant/${id}$`));
  await settle(page);
  check(!(await mini.isVisible()), `${label}: it stands aside on the chant's own page`);
  check(await eventually(async () => (await page.locator("[data-role=play]").getAttribute("aria-pressed")) === "true"),
    `${label}: the chant's page shows its chant singing`);
  check(await page.evaluate(() => window.__sameDocument === true), `${label}: the names open the chant by live navigation`);

  // A full page load ends the <audio>: the player comes back paused where it stood
  await page.waitForTimeout(2500);
  await page.goto(BASE_URL + "/explore");
  await settle(page);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root], #live-debugger { display: none !important; }" });
  check(await eventually(() => mini.isVisible()), `${label}: after a full page load it comes back`);
  const restored = await page.locator("audio#site-chant-audio").evaluate((a) => ({ paused: a.paused, time: a.currentTime }));
  check(restored.paused && restored.time > 0, `${label}: paused where it stood`, JSON.stringify(restored));
  await play.click();
  check(await eventually(sounding, 30000), `${label}: its disc goes on from there`);

  await mini.locator("[data-role=mini-close]").click();
  check(await eventually(async () => !(await mini.isVisible())), `${label}: close puts it away`);
  check((await sounding()) === 0, `${label}: and the chant with it`);
  check(await page.evaluate(() => sessionStorage.getItem("lv:chant-player") === null), `${label}: nothing kept once closed`);

  // What is read back is checked: a recording that a browser would fetch
  // from another host ("/\\host", read as "//host") is never restored
  await page.evaluate((chant) => {
    const current = { id: chant, src: "/\\evil.example/x.m4a", facts: { latin: "X", href: `/chant/${chant}` } };
    sessionStorage.setItem("lv:chant-player", JSON.stringify({ current, queue: null, waiting: false, time: 3, rate: 1 }));
  }, id);
  await page.goto(BASE_URL + "/mysteries");
  await settle(page);
  const tampered = await page.locator("audio#site-chant-audio").evaluate((a) => a.getAttribute("src") || "");
  check(!tampered.includes("evil.example"), `${label}: a recording from another host is never restored`, tampered);
  check(!(await mini.isVisible()), `${label}: and no player stands for it`);
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

// Pause Between Chants, one kept choice as the app keeps it: turned on on
// a set's page, it is still on there after a live navigation away and
// back while the set sings on; at a chant's end the set waits for a tap
// (the mini player names the next chant and keeps the line full), and so
// does a shelf's Play all. The recordings come from the site's bucket.
async function checkChantPauses(browser, vp) {
  const label = `${vp.name} pause between chants`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);
  const audio = page.locator("audio#site-chant-audio");
  const mini = page.locator("#chant-mini");
  const sounding = () => audio.evaluate((a) => (!a.paused && a.currentTime > 0 ? a.currentTime : 0));
  // To the last moment of the chant sounding, so its end comes now
  const toTheEnd = () =>
    audio.evaluate((a) => {
      a.currentTime = Math.max(0, a.duration - 0.4);
    });

  await page.goto(BASE_URL + "/chant/sets/benediction");
  await settle(page);
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root], #live-debugger { display: none !important; }" });
  const box = page.locator("[data-pauses-between]");
  check(!(await box.isChecked()), `${label}: off at first`);
  await page.locator("[data-role=pauses-between]").click();
  check(await box.isChecked(), `${label}: the switch turns it on`);
  check(await page.evaluate(() => localStorage.getItem("lv:chant-pauses-between") === "true"), `${label}: kept in this browser`);

  await page.locator("[data-role=play-all]").click();
  check(await eventually(sounding, 30000), `${label}: the set sings`);

  await page.evaluate(() => (window.__sameDocument = true));
  await page.locator('#site-footer a[href="/mysteries"]').click();
  await page.waitForURL(/\/mysteries$/);
  await settle(page);
  await page.goBack();
  await page.waitForURL(/\/chant\/sets\/benediction$/);
  await settle(page);
  check(await page.evaluate(() => window.__sameDocument === true), `${label}: away and back by live navigation`);
  check(await eventually(() => box.isChecked()), `${label}: the switch still shows it on`);
  check((await sounding()) > 0, `${label}: the set sang on meanwhile`);

  await audio.evaluate((a) => a.duration > 0 || new Promise((ok) => a.addEventListener("loadedmetadata", ok, { once: true })));
  await toTheEnd();
  const word = page.locator("[data-play-set-word]");
  check(await eventually(async () => (await word.textContent()).trim() === "Play next", 15000), `${label}: the set waits with Play next`);
  check((await sounding()) === 0, `${label}: nothing sounds while it waits`);
  check(/waiting for you$/.test((await mini.locator("[data-role=mini-subtitle]").textContent()).trim()), `${label}: the mini player says it waits`);
  const disc = await mini.locator("[data-role=mini-play]").getAttribute("aria-label");
  check(/^Play [^,]+, .+/.test(disc), `${label}: its disc names the next chant, Latin and English`, disc);
  check((await mini.locator("[data-role=mini-progress]").evaluate((el) => el.style.transform)) === "scaleX(1)",
    `${label}: the line stays full while it waits`);
  await page.locator("[data-role=play-all]").click();
  check(await eventually(sounding, 30000), `${label}: Play next sings the next chant`);

  // A shelf's Play all waits too: the choice is the player's, not the set's
  await page.goto(BASE_URL + "/chant/sections/mass");
  await settle(page);
  const all = page.locator("[data-play-all]");
  await all.click();
  check(await eventually(sounding, 30000), `${label}: a shelf's Play all sings`);
  await toTheEnd();
  const allWord = all.locator("[data-play-all-word]");
  check(await eventually(async () => (await allWord.textContent()).trim() === "Play next", 15000),
    `${label}: the shelf waits between chants`);
  check((await sounding()) === 0, `${label}: nothing sounds while the shelf waits`);
  await all.click();
  check(await eventually(sounding, 30000), `${label}: the shelf goes on at a tap`);

  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

// Explore: the directory at rest, the header's link to it, and the one
// search riding in the link. "Salve", "ave maria" and "Pater" find a
// prayer and a chant, accents and case aside; "annunciation" finds a
// mystery and opens its devotion's page.
async function checkExplore(browser, vp) {
  const label = `${vp.name} explore`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/explore");
  await settle(page);
  check((await page.locator("[data-role=devotion]").count()) === 5, `${label}: the five devotions`);
  check((await page.locator('#site-header a[href="/explore"]').count()) >= 1, `${label}: the header links Explore`);
  check((await page.locator('[data-role=tile][href="/missal"]').count()) === 1, `${label}: Mass & Hours opens the Daily Missal`);
  const shelf = page.locator("#explore-browse-reading-shelf");
  check((await shelf.locator("[data-role=book]").count()) === 6, `${label}: True Devotion and the five books on the reading shelf`);
  check((await shelf.locator('a[href="/spiritual-reading"]').count()) === 1, `${label}: the reading shelf's All books`);
  await noHorizontalScroll(page, `${label} (at rest)`);

  // A reading under way in this browser hangs the ribbon on its cover.
  await page.evaluate(() =>
    localStorage.setItem(
      "lv:spiritual-reading:imitation-of-christ",
      JSON.stringify({ edition: "e2e", chapter: 2, paragraph: 0, read: [], at: Date.now() })
    )
  );
  await page.reload();
  await settle(page);
  const ribbon = shelf.locator('[data-role=ribbon][data-book="imitation-of-christ"]');
  check(await eventually(async () => await ribbon.isVisible()), `${label}: a book under way wears its ribbon`);
  check(!(await shelf.locator('[data-role=ribbon][data-book="story-of-a-soul"]').isVisible()), `${label}: a book not begun wears none`);

  await page.goto(BASE_URL + "/explore?q=kempis");
  await settle(page);
  check(
    (await page.locator('#explore-results a[href="/spiritual-reading/imitation-of-christ"]').count()) === 1,
    `${label}: "kempis" finds the Imitation of Christ`
  );
  await page.goto(BASE_URL + "/explore");
  await settle(page);

  await page.getByRole("searchbox", { name: /search/i }).fill("Salve");
  const searched = await eventually(() => new URL(page.url()).searchParams.get("q") === "Salve");
  check(searched, `${label}: the search rides in the link`, page.url());
  const salve = await eventually(async () =>
    (await page.locator('#explore-results a[href="/chant/salve_regina_simple"]').count()) > 0 &&
    (await page.locator('#explore-results a[href="/prayers/hail_holy_queen"]').count()) > 0);
  check(salve, `${label}: "Salve" finds the Salve Regina, prayer and chant`);
  await noHorizontalScroll(page, `${label} (results)`);

  for (const [query, prayer, chant] of [["ave maria", "hail_mary", "ave_maria"], ["PÂTER", "our_father", "pater_noster"]]) {
    await page.goto(BASE_URL + "/explore?" + new URLSearchParams({ q: query }));
    await settle(page);
    const prayerFound = (await page.locator(`#explore-results a[href="/prayers/${prayer}"]`).count()) > 0;
    const chantFound = (await page.locator(`#explore-results a[href="/chant/${chant}"]`).count()) > 0;
    check(prayerFound && chantFound, `${label}: "${query}" finds the prayer and the chant`);
  }

  await page.goto(BASE_URL + "/explore?q=annunciation");
  await settle(page);
  const best = page.locator('[data-role=best] a[href="/mysteries/joyful"]');
  check((await best.count()) === 1, `${label}: "annunciation" finds the mystery`);
  if ((await best.count()) === 1) {
    await best.click();
    const opened = await eventually(() => new URL(page.url()).pathname === "/mysteries/joyful");
    check(opened, `${label}: the mystery opens its devotion's page`, page.url());
  }

  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));
  await context.close();
}

// Spiritual Reading: the shelf lists the five books; a book's text comes
// from Project Gutenberg through the server, which may not reach it from a
// dev machine, so the book's page either shows its contents or says the
// library could not be reached, and the log says which. With the text,
// Begin reading opens the first chapter, the chapter after it steps on,
// and the book's page then offers Continue with the earlier chapter read.
// An unknown book and a chapter that is not a number are 404s.
async function checkSpiritualReading(browser, vp) {
  const label = `${vp.name} spiritual reading`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  await page.goto(BASE_URL + "/spiritual-reading");
  await settle(page);
  check((await page.locator("[data-role=book]").count()) === 5, `${label}: the shelf holds five books`);
  await page.locator('[data-role=book][data-book="practice-of-the-presence-of-god"]').click();
  await eventually(() => new URL(page.url()).pathname === "/spiritual-reading/practice-of-the-presence-of-god");

  const outcome = await eventually(async () => {
    if ((await page.locator("[data-role=contents]").count()) > 0) return "text";
    if ((await page.locator("[data-role=unavailable]").count()) > 0) return "unreachable";
    return false;
  }, 40000);
  check(Boolean(outcome), `${label}: the book arrives or says it could not be reached`);
  console.log(`        the book: ${outcome === "text" ? "text from Project Gutenberg" : outcome || "neither"}`);
  await noHorizontalScroll(page, `${label} (book)`);

  if (outcome === "text") {
    const act = page.locator("[data-role=read-act]");
    check((await act.innerText()).trim().toUpperCase().startsWith("BEGIN READING"), `${label}: a first visit offers Begin reading`);
    await act.click();
    check(
      await eventually(() => new URL(page.url()).pathname === "/spiritual-reading/practice-of-the-presence-of-god/1"),
      `${label}: Begin reading opens the first chapter`,
      page.url()
    );
    check(await eventually(async () => (await page.locator("[data-role=chapter-text] [data-p]").count()) > 0), `${label}: the chapter has its text`);
    await noHorizontalScroll(page, `${label} (chapter)`);
    await fullPageShot(page, `${vp.name}-spiritual-reading-chapter`);
    await page.locator("[data-role=next-chapter]").click();
    check(
      await eventually(() => new URL(page.url()).pathname === "/spiritual-reading/practice-of-the-presence-of-god/2"),
      `${label}: the chapter after steps on`,
      page.url()
    );
    await eventually(async () => (await page.locator("[data-role=chapter-text]").count()) > 0);
    await page.goto(BASE_URL + "/spiritual-reading/practice-of-the-presence-of-god");
    await settle(page);
    const continued = await eventually(async () => /^CONTINUE/.test((await act.innerText()).trim().toUpperCase()));
    check(continued, `${label}: the book offers Continue where this browser left off`);
    check((await page.locator("[data-role=chapter-row][data-read]").count()) >= 1, `${label}: the chapter stepped past is read`);
  }
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  if (outcome === "text") {
    // The LibriVox recording: the book's rows wear listen chips, or the page
    // says the recording could not be reached (the server could not reach
    // LibriVox). Real playback is not required: the stream comes from the
    // Internet Archive, which a test run may not reach.
    const recording = await eventually(async () => {
      if ((await page.locator("[data-act=listen]").count()) > 0) return "tracks";
      if ((await page.locator("[data-role=recording-unavailable]").count()) > 0) return "unreachable";
      return false;
    }, 30000);
    check(Boolean(recording), `${label}: the recording arrives or says it could not be reached`);
    console.log(`        the recording: ${recording === "tracks" ? "track list from LibriVox" : recording || "neither"}`);

    if (recording === "tracks") {
      check(
        (await page.locator('[data-act=listen][data-chapter="0"]').count()) === 0 &&
          (await page.locator('[data-act=listen][data-chapter="1"]').count()) === 1,
        `${label}: the preface has no chip, the first conversation has one`
      );
      check(
        (await page.locator("[data-role=recording-credit]").count()) > 0,
        `${label}: the credit names LibriVox's volunteers`
      );
      // Before the page connects there is no hook to answer the voice's
      // controls, so they stand dimmed and take no tap (a slow phone).
      {
        const unconnected = await freshPage(browser, vp, []);
        // The app's script held back, as on a slow connection: the page is
        // drawn, but nothing has connected yet.
        await unconnected.context.route(/\/assets\/js\/app\.js/, () => {});
        await unconnected.page.goto(BASE_URL + "/spiritual-reading/practice-of-the-presence-of-god/2", {
          waitUntil: "commit"
        });
        const waiting = unconnected.page.locator("[data-act=hear]");
        await waiting.waitFor({ state: "attached", timeout: 10000 }).catch(() => {});
        if ((await waiting.count()) === 1) {
          const style = await waiting.evaluate((el) => getComputedStyle(el).pointerEvents);
          check(style === "none", `${label}: Hear this read takes no tap until the page connects`, style);
        }
        await unconnected.context.close();
      }
      await page.goto(BASE_URL + "/spiritual-reading/practice-of-the-presence-of-god/2");
      await settle(page);
      await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });
      const hear = page.locator("[data-act=hear]");
      check(await eventually(async () => (await hear.count()) === 1), `${label}: the chapter offers Hear this read`);
      check(
        (await hear.evaluate((el) => getComputedStyle(el).pointerEvents)) !== "none",
        `${label}: Hear this read comes alive with the connection`
      );
      if ((await hear.count()) === 1) {
        check(await page.locator("[data-role=player]").isHidden(), `${label}: the player waits until the reading is asked for`);
        await hear.click();
        const shown = await eventually(async () => await page.locator("[data-role=player]").isVisible());
        check(shown, `${label}: Hear this read brings up the player`);
        const title = (await page.locator("[data-role=player] [data-role=mini-title]").innerText()).trim();
        check(title === "First Conversation", `${label}: the player names the reading`, title);
        await page.locator("[data-role=player] [data-act=expand]").click();
        check(await page.locator("[data-role=panel]").isVisible(), `${label}: the player opens from its title`);
        await noHorizontalScroll(page, `${label} (player)`);
        await fullPageShot(page, `${vp.name}-spiritual-reading-player`);
      }
    }
  }

  for (const unknown of ["/spiritual-reading/nowhere", "/spiritual-reading/imitation-of-christ/zero"]) {
    const response = await page.goto(BASE_URL + unknown);
    check(response && response.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${response && response.status()}`);
  }
  await context.close();
}

// True Devotion: the old address opens the book rather than redirecting
// home, Begin reading opens the first chapter, Next chapter steps on, and
// the place kept in this browser turns the act into Continue reading. A
// paragraph's number chooses it and Bookmark keeps it. Unknown chapters
// are 404s.
async function checkTrueDevotion(browser, vp) {
  const label = `${vp.name} true devotion`;
  console.log(label);
  const errors = [];
  const { context, page } = await freshPage(browser, vp, errors);

  const response = await page.goto(BASE_URL + "/true-devotion");
  await settle(page);
  check(response && response.status() === 200, `${label}: /true-devotion answers 200`, `got ${response && response.status()}`);
  check(new URL(page.url()).pathname === "/true-devotion", `${label}: /true-devotion no longer redirects`, page.url());
  await page.addStyleTag({ content: "[data-tidewave-toolbar-root] { display: none !important; }" });

  const act = page.locator("[data-role=read-act]");
  check(/Begin reading/i.test(await act.innerText()), `${label}: a new reader is offered Begin reading`);
  await act.click();
  const opened = await eventually(() => new URL(page.url()).pathname === "/true-devotion/introduction");
  check(opened, `${label}: Begin reading opens the Introduction`, page.url());
  await settle(page);

  await page.locator("[data-role=next-chapter]").click();
  const stepped = await eventually(() => new URL(page.url()).pathname === "/true-devotion/necessity");
  check(stepped, `${label}: Next chapter steps on`, page.url());
  await settle(page);
  const heading = await eventually(async () => (await page.locator("h1").textContent()).includes("Necessity"));
  check(heading, `${label}: the next chapter is on the page`);

  await page.mouse.wheel(0, 1200);
  await page.waitForTimeout(400);
  await page.locator('[data-select="2"]').click();
  await page.locator("[data-role=passage-bar] [data-act=mark]").click();
  const marked = await eventually(async () => (await page.locator('[data-p="2"][data-marked]').count()) === 1);
  check(marked, `${label}: Bookmark marks the paragraph`);
  await noHorizontalScroll(page, `${label} (chapter)`);

  await page.goto(BASE_URL + "/true-devotion");
  await settle(page);
  const resumed = await eventually(async () => /Continue reading/i.test(await act.innerText()));
  check(resumed, `${label}: the place kept turns the act into Continue reading`);
  const href = await act.getAttribute("href");
  check(/^\/true-devotion\/necessity(#p-\d+)?$/.test(href || ""), `${label}: Continue reading resumes the chapter`, href);

  // Opened from the contents (no #p-N), the chapter resumes the kept
  // paragraph and leaves the place as it was.
  const keptPlace = () =>
    page.evaluate(() => {
      try {
        return JSON.parse(localStorage.getItem("lv:true-devotion:place"));
      } catch (_e) {
        return null;
      }
    });
  const kept = await keptPlace();
  check(kept && kept.chapter === "necessity" && kept.paragraph > 0, `${label}: scrolling keeps a paragraph as the place`, JSON.stringify(kept));
  await page.locator('[data-role=chapter-row][data-chapter="necessity"]').click();
  const reopened = await eventually(() => new URL(page.url()).pathname === "/true-devotion/necessity");
  check(reopened, `${label}: a contents row opens the chapter`, page.url());
  await settle(page);
  if (kept && kept.paragraph > 0) {
    const landed = await eventually(async () => {
      const top = await page.locator(`#p-${kept.paragraph}`).evaluate((el) => el.getBoundingClientRect().top);
      return top >= 0 && top < 160;
    });
    check(landed, `${label}: a chapter opened from the contents resumes the kept paragraph`, `p-${kept.paragraph}`);
    const after = await keptPlace();
    check(after && after.chapter === "necessity" && after.paragraph >= kept.paragraph, `${label}: opening the chapter keeps the place`, JSON.stringify(after));
  }
  check(errors.length === 0, `${label}: no console errors`, errors.join(" | "));

  for (const unknown of ["/true-devotion/nowhere"]) {
    const res = await page.goto(BASE_URL + unknown);
    check(res && res.status() === 404, `${vp.name} ${unknown}: answers 404`, `got ${res && res.status()}`);
  }
  await context.close();
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

  // On a phone the choices are folded behind one row; open them.
  const openChoices = async () => {
    const toggle = page.locator("#choices-toggle");
    if (await toggle.isVisible()) {
      await toggle.click();
      await page.waitForTimeout(200);
    }
  };

  await page.goto(`${BASE_URL}/mysteries/joyful`);
  await settle(page);
  await openChoices();
  check(await countingShown(), `${label}: Counting shows while the audio is meditation only`);

  await choose("Whole Rosary read to you");
  check(await radio("Whole Rosary read to you").isChecked(), `${label}: Whole Rosary read to you is selected`);
  check(!(await countingShown()), `${label}: Counting disappears with the whole Rosary aloud`);
  const aloudHrefs = await prayHrefs();
  check(aloudHrefs.length > 0 && aloudHrefs.every((h) => h.includes("aloud=true")), `${label}: Pray links gain aloud=true`, aloudHrefs[0]);
  await noHorizontalScroll(page, `${label} (aloud)`);

  await page.reload();
  await settle(page);
  await openChoices();
  check(
    await eventually(() => radio("Whole Rosary read to you").isChecked()),
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
  await openChoices();
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

    await checkHooks(page, errors, vp);
    for (const spec of PAGES) await checkPage(page, errors, vp, spec);
    await checkPrayFlow(page, errors, vp);
    await checkAppPage(page, vp);
    await checkRedirects(page, vp);
    await context.close();

    await checkCategoryChoices(browser, vp);
    await checkPrayerScreen(browser, vp);
    await checkScriptural(browser, vp);
    await checkSetlessAndUnknown(browser, vp);
    await checkPrayers(browser, vp);
    await checkHours(browser, vp);
    await checkMissal(browser, vp);
    await checkTrueDevotion(browser, vp);
    await checkSpiritualReading(browser, vp);
    await checkChant(browser, vp);
    await checkChantMiniPlayer(browser, vp);
    await checkChantPauses(browser, vp);
    await checkConsecration(browser, vp);
    await checkTodaysPrayer(browser, vp);
    await checkExplore(browser, vp);
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
