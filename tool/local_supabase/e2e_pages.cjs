// Browser test: sign in to the office web build, then open each route and screenshot it.
// PW=$(npm root -g)/playwright node tool/local_supabase/e2e_pages.cjs <baseUrl> <user> <password> <outDir> <route>[@x,y;x,y...] ...
// A route may carry steps after '@', separated by ';': 'x,y' clicks, 't=text' types, 'k=Enter' presses a key,
// 'f=/path/file.jpg' answers the file picker opened by the next click.
const { chromium } = require(process.env.PW);
(async () => {
  const [base, user, pass, out, ...routes] = process.argv.slice(2);
  const b = await chromium.launch({ args: ['--no-proxy-server'] });
  const p = await b.newPage({ viewport: { width: 1366, height: 768 }, locale: 'en-US' });
  const errors = [];
  // file pickers: registered up front, because Playwright enables interception asynchronously
  let pendingFile = null;
  p.on('filechooser', async (fc) => {
    if (pendingFile) { await fc.setFiles(pendingFile); pendingFile = null; } else { await fc.setFiles([]); }
  });
  p.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  p.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await p.goto(base, { waitUntil: 'networkidle' });
  await p.waitForTimeout(4000);
  await p.keyboard.type(user, { delay: 20 });
  await p.keyboard.press('Tab');
  await p.keyboard.type(pass, { delay: 20 });
  await p.keyboard.press('Enter');
  await p.waitForTimeout(4000);
  console.log('after login:', p.url());
  for (const r of routes) {
    const [route, clicks] = r.split('@');
    await p.evaluate((h) => { window.location.hash = h; }, route);
    await p.waitForTimeout(3500);
    for (const c of (clicks || '').split(';').filter(Boolean)) {
      if (c.startsWith('f=')) { pendingFile = c.slice(2); continue; }                // next click opens a file picker
      if (c.startsWith('t=')) await p.keyboard.type(c.slice(2), { delay: 20 });       // type text
      else if (c.startsWith('k=')) await p.keyboard.press(c.slice(2));                // press a key
      else {                                                                          // click x,y
        const [x, y] = c.split(',').map(Number);
        await p.mouse.click(x, y);
      }
      await p.waitForTimeout(1500);
    }
    const name = (route.replace(/[^a-z0-9]+/gi, '_') + (clicks ? '_' + clicks.replace(/[^0-9a-z]+/gi, '_').slice(0, 40) : '')).replace(/^_|_$/g, '');
    await p.screenshot({ path: `${out}/${name || 'root'}.png` });
    console.log('shot', name, p.url());
  }
  if (errors.length) console.log(errors.slice(0, 10).join('\n'));
  await b.close();
})();
