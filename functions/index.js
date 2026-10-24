// Mum Brain – shared list notifications.
// When a phone writes a (scrambled) change to families/{fid}/events, this sends it to every other phone
// in that family through Apple's notification service, then deletes the event.
// It can't read the change: the phones scramble it, and the notification extension on the receiving
// phone unscrambles it. If that ever fails, the phone shows the plain fallback text below instead.
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const http2 = require('node:http2');
const crypto = require('node:crypto');

initializeApp();

const APNS_KEY_P8 = defineSecret('APNS_KEY_P8'); // the AuthKey_XXXX.p8 file's text
const APNS_KEY_ID = defineSecret('APNS_KEY_ID'); // its Key ID
const TEAM_ID = '327WHDC3C5';
const TOPIC = 'com.gmoghul.mumbrainsorted';      // the app's App ID
const APNS = 'https://api.push.apple.com';        // TestFlight and App Store apps

let jwt = null, jwtAt = 0;
function apnsToken() {
  // Apple accepts the same token for up to an hour; refresh it every 40 minutes
  if (jwt && Date.now() - jwtAt < 40 * 60 * 1000) return jwt;
  const head = Buffer.from(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID.value().trim() })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) })).toString('base64url');
  const sig = crypto.sign('sha256', Buffer.from(head + '.' + claims), { key: APNS_KEY_P8.value(), dsaEncoding: 'ieee-p1363' });
  jwt = head + '.' + claims + '.' + sig.toString('base64url');
  jwtAt = Date.now();
  return jwt;
}

function send(client, token, payload, quiet) {
  return new Promise(resolve => {
    const body = JSON.stringify(payload);
    const req = client.request({
      ':method': 'POST',
      ':path': '/3/device/' + token,
      authorization: 'bearer ' + apnsToken(),
      'apns-topic': TOPIC,
      'apns-push-type': 'alert',
      'apns-priority': quiet ? '5' : '10',
      'apns-expiration': String(Math.floor(Date.now() / 1000) + 2 * 24 * 3600),
      'content-type': 'application/json',
      'content-length': Buffer.byteLength(body),
    });
    let status = 0, data = '';
    req.setEncoding('utf8');
    req.on('response', h => { status = h[':status']; });
    req.on('data', c => { data += c; });
    req.on('end', () => {
      let reason = '';
      try { reason = JSON.parse(data).reason || ''; } catch (e) { /* empty body on success */ }
      resolve({ status, reason });
    });
    req.on('error', e => resolve({ status: 0, reason: String(e && e.message) }));
    req.setTimeout(10000, () => { req.close(); resolve({ status: 0, reason: 'timeout' }); });
    req.end(body);
  });
}

exports.sharedChange = onDocumentCreated(
  {
    document: 'families/{fid}/events/{eid}',
    region: 'europe-west2', // same place as the database (London)
    secrets: [APNS_KEY_P8, APNS_KEY_ID],
    memory: '256MiB',
    maxInstances: 5,
    retry: false,
  },
  async event => {
    const snap = event.data;
    if (!snap) return;
    const e = snap.data() || {};
    const { fid } = event.params;
    try {
      if (e.v !== 1 || typeof e.iv !== 'string' || typeof e.ct !== 'string') return;
      const devices = await getFirestore().collection(`families/${fid}/devices`).get();
      const targets = devices.docs.filter(d => d.id !== e.from && typeof d.get('t') === 'string');
      if (!targets.length) return;
      const client = http2.connect(APNS);
      client.on('error', () => {});
      try {
        await Promise.all(targets.map(async d => {
          const quiet = d.get('m') === 'quiet';
          const aps = {
            alert: { title: 'Shared list', body: 'A shared job has changed. Open the app to see what’s new.' },
            'mutable-content': 1,
            'thread-id': 'shared',
          };
          if (quiet) aps['interruption-level'] = 'passive';
          else aps.sound = 'default';
          const r = await send(client, d.get('t'), { aps, mb: { iv: e.iv, ct: e.ct } }, quiet);
          if (r.status === 410 || (r.status === 400 && /BadDeviceToken|DeviceTokenNotForTopic/.test(r.reason))) {
            await d.ref.delete(); // that phone has removed the app or changed address; it re-registers when opened
          } else if (r.status !== 200) {
            console.warn('APNs', r.status, r.reason);
          }
        }));
      } finally {
        client.close();
      }
    } finally {
      await snap.ref.delete().catch(() => {});
    }
  }
);
