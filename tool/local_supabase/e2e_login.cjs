// Browser test: sign in to the office web build and screenshot the result.
// PW=$(npm root -g)/playwright node tool/local_supabase/e2e_login.cjs http://127.0.0.1:8088/ operator1 Wasa@1234 /tmp/op
// usage: node e2e_login.js <url> <user> <password> <outPrefix>
const { chromium } = require(process.env.PW);
(async () => {
  const [url, user, pass, out] = process.argv.slice(2);
  const b = await chromium.launch({ args: ['--no-proxy-server'] });
  const p = await b.newPage({ viewport: { width: 1366, height: 768 }, locale: 'en-US' });
  p.on('pageerror', e => console.log('pageerror:', e.message));
  p.on('console', m => { if (m.type() === 'error') console.log('console error:', m.text()); });
  await p.goto(url, { waitUntil: 'networkidle' });
  await p.waitForTimeout(5000);
  await p.screenshot({ path: out + '_1_login.png' });
  await p.keyboard.type(user, { delay: 30 });
  await p.keyboard.press('Tab');
  await p.keyboard.type(pass, { delay: 30 });
  await p.keyboard.press('Enter');
  await p.waitForTimeout(6000);
  console.log('url after login:', p.url());
  await p.screenshot({ path: out + '_2_after.png' });
  await b.close();
})();
