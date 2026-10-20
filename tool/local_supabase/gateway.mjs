// Local Supabase-lite gateway (dev/test only; NOT used with Supabase Cloud).
// One URL like https://<ref>.supabase.co:
//   /auth/v1/*     -> Supabase Auth (GoTrue) on :9999
//   /rest/v1/*     -> PostgREST on :3000
//   /storage/v1/*  -> a tiny file store in ./.data/storage (permission checks via PostgREST RPCs)
// Adds CORS so the Flutter web build can call it.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const PORT = +(process.env.GATEWAY_PORT || 54321);
const DATA = process.env.STORAGE_DIR || path.resolve('.data/storage');
const PUBLIC_BUCKETS = new Set(['vehicle-photos']);
const upstream = { '/auth/v1': 9999, '/rest/v1': 3000 };

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD',
  'access-control-expose-headers': 'content-range, content-profile, x-supabase-api-version',
};

function send(res, code, body, headers = {}) {
  const isBuf = Buffer.isBuffer(body);
  res.writeHead(code, { ...cors, 'content-type': isBuf ? headers['content-type'] || 'application/octet-stream' : 'application/json', ...headers });
  res.end(isBuf ? body : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function proxy(req, res, port, pathRest) {
  const p = http.request(
    { host: '127.0.0.1', port, path: pathRest, method: req.method, headers: { ...req.headers, host: `127.0.0.1:${port}` } },
    (u) => {
      res.writeHead(u.statusCode, { ...u.headers, ...cors });
      u.pipe(res);
    },
  );
  p.on('error', (e) => send(res, 502, { message: `upstream ${port} unavailable: ${e.message}` }));
  req.pipe(p);
}

// ask PostgREST (as the caller) whether an RPC returns true
function rpc(name, auth, args = {}) {
  return new Promise((resolve) => {
    const body = JSON.stringify(args);
    const r = http.request(
      { host: '127.0.0.1', port: 3000, path: `/rpc/${name}`, method: 'POST',
        headers: { 'content-type': 'application/json', authorization: auth || '', 'content-length': Buffer.byteLength(body) } },
      (u) => { let s = ''; u.on('data', (c) => (s += c)); u.on('end', () => resolve(u.statusCode === 200 && s.trim() === 'true')); },
    );
    r.on('error', () => resolve(false));
    r.end(body);
  });
}

async function canWrite(bucket, objectPath, auth) {
  if (bucket === 'vehicle-photos') return rpc('app_is_admin', auth);
  if (bucket === 'site-photos') return rpc('app_can_upload_site_photo', auth, { p_challan_id: objectPath.split('/')[0] });
  return false;
}

async function canRead(bucket, objectPath, auth) {
  if (PUBLIC_BUCKETS.has(bucket)) return true;
  if (bucket === 'site-photos') return rpc('app_can_see_challan', auth, { p_challan_id: objectPath.split('/')[0] });
  return false;
}

function safePath(bucket, objectPath) {
  const full = path.resolve(DATA, bucket, objectPath);
  if (!full.startsWith(path.resolve(DATA, bucket) + path.sep)) throw new Error('bad path');
  return full;
}

// multipart/form-data: return the first file part's bytes and type
function firstFilePart(buf, contentType) {
  const m = /boundary=(?:"([^"]+)"|([^;]+))/.exec(contentType);
  if (!m) return { data: buf, type: contentType };
  const boundary = Buffer.from('--' + (m[1] || m[2]));
  let start = buf.indexOf(boundary);
  while (start !== -1) {
    const headEnd = buf.indexOf('\r\n\r\n', start);
    const next = buf.indexOf(boundary, headEnd);
    if (headEnd === -1 || next === -1) break;
    const head = buf.slice(start, headEnd).toString();
    if (/filename=/.test(head) || /name="file"|name=""/.test(head)) {
      const type = (/content-type:\s*([^\r\n]+)/i.exec(head) || [])[1] || 'application/octet-stream';
      return { data: buf.slice(headEnd + 4, next - 2), type };
    }
    start = next;
  }
  return { data: buf, type: 'application/octet-stream' };
}

async function storage(req, res, rest) {
  const url = new URL(rest, 'http://x');
  const parts = url.pathname.split('/').filter(Boolean).map(decodeURIComponent); // object, [public|authenticated], bucket, ...path
  const auth = req.headers.authorization;
  if (parts[0] !== 'object') return send(res, 404, { message: 'not found' });

  if (req.method === 'GET' || req.method === 'HEAD') {
    const pub = parts[1] === 'public' || parts[1] === 'authenticated';
    const bucket = pub ? parts[2] : parts[1];
    const objectPath = parts.slice(pub ? 3 : 2).join('/');
    if (parts[1] === 'public' && !PUBLIC_BUCKETS.has(bucket)) return send(res, 400, { message: 'Bucket not public' });
    if (!(await canRead(bucket, objectPath, auth))) return send(res, 403, { message: 'not allowed' });
    try {
      const file = safePath(bucket, objectPath);
      const type = fs.existsSync(file + '.type') ? fs.readFileSync(file + '.type', 'utf8') : 'application/octet-stream';
      return send(res, 200, fs.readFileSync(file), { 'content-type': type, 'cache-control': 'max-age=60' });
    } catch {
      return send(res, 404, { message: 'Object not found' });
    }
  }

  if (req.method === 'POST' || req.method === 'PUT') {
    const bucket = parts[1];
    const objectPath = parts.slice(2).join('/');
    if (!(await canWrite(bucket, objectPath, auth))) return send(res, 403, { statusCode: '403', error: 'Unauthorized', message: 'new row violates row-level security policy' });
    const body = await readBody(req);
    const ct = req.headers['content-type'] || 'application/octet-stream';
    const { data, type } = ct.startsWith('multipart/') ? firstFilePart(body, ct) : { data: body, type: ct };
    const file = safePath(bucket, objectPath);
    if (req.method === 'POST' && fs.existsSync(file) && req.headers['x-upsert'] !== 'true') {
      return send(res, 400, { statusCode: '409', error: 'Duplicate', message: 'The resource already exists' });
    }
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, data);
    fs.writeFileSync(file + '.type', type);
    return send(res, 200, { Key: `${bucket}/${objectPath}`, Id: objectPath });
  }

  if (req.method === 'DELETE') {
    const bucket = parts[1];
    const body = JSON.parse((await readBody(req)).toString() || '{}');
    const removed = [];
    for (const p of body.prefixes || []) {
      if (!(await canWrite(bucket, p, auth))) return send(res, 403, { message: 'not allowed' });
      try { const f = safePath(bucket, p); fs.rmSync(f); fs.rmSync(f + '.type', { force: true }); removed.push({ name: p }); } catch {}
    }
    return send(res, 200, removed);
  }
  return send(res, 405, { message: 'method not allowed' });
}

http
  .createServer(async (req, res) => {
    try {
      if (req.method === 'OPTIONS') return send(res, 204, '');
      for (const [prefix, port] of Object.entries(upstream)) {
        if (req.url.startsWith(prefix)) return proxy(req, res, port, req.url.slice(prefix.length) || '/');
      }
      if (req.url.startsWith('/storage/v1/')) return await storage(req, res, req.url.slice('/storage/v1'.length));
      return send(res, 404, { message: 'not found' });
    } catch (e) {
      return send(res, 500, { message: String(e) });
    }
  })
  .listen(PORT, '0.0.0.0', () => console.log(`gateway on http://127.0.0.1:${PORT}`));
