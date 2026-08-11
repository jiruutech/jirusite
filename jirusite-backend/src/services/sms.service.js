/**
 * SMS service — wraps AfroMessage / Geez SMS (or any Ethiopian SMS aggregator).
 * In development/test the message is just logged.
 */
const https = require('https');
const http = require('http');

async function sendSms(to, message) {
  if (process.env.NODE_ENV !== 'production') {
    console.log(`[SMS stub] To: ${to} | Message: ${message}`);
    return { success: true, stub: true };
  }

  const body = JSON.stringify({
    to,
    message,
    sender: process.env.SMS_SENDER_ID || 'JIRUSite',
  });

  return new Promise((resolve, reject) => {
    const url = new URL(process.env.SMS_API_URL);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.SMS_API_TOKEN}`,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const client = url.protocol === 'https:' ? https : http;
    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve({ raw: data });
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

module.exports = { sendSms };
