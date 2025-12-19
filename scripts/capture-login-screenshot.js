import puppeteer from 'puppeteer';

(async () => {
  const url = process.env.CAPTURE_URL || 'http://127.0.0.1:8000/login';
  const out = 'tests/legacy/Browser/screenshots/login-puppeteer-screenshot.png';

  try {
    const browser = await puppeteer.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });

    // Wait for the page to be stable
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });

    // Give a small extra pause if there are client-side races
    await page.waitForTimeout(500);

    await page.screenshot({ path: out, fullPage: true });
    console.error('PUPPETEER: screenshot saved', out);

    await browser.close();
    process.exit(0);
  } catch (err) {
    console.error('PUPPETEER: screenshot failed', err && err.message ? err.message : err);
    try {
      // Write a failure marker so artifacts show it failed
      const fs = await import('fs');
      fs.writeFileSync('tests/legacy/Browser/screenshots/puppeteer-capture-failed.txt', String(err.stack || err));
    } catch (__) {
      // ignore
    }

    process.exit(1);
  }
})();