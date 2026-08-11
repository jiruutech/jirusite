/**
 * JIRUSite API smoke test — run with: node scripts/smoke-test.js
 * Tests every major endpoint end-to-end against the live dev server.
 */
require('dotenv').config();
const http = require('http');

const BASE = `http://localhost:${process.env.PORT || 3000}/api`;
let passed = 0;
let failed = 0;

// ── HTTP helpers ──────────────────────────────────────────────────────────────

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const options = {
      hostname: 'localhost',
      port: process.env.PORT || 3000,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': payload ? Buffer.byteLength(payload) : 0,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

const get = (path, token) => request('GET', path, null, token);
const post = (path, body, token) => request('POST', path, body, token);
const patch = (path, body, token) => request('PATCH', path, body, token);

function ok(label, condition, detail = '') {
  if (condition) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    console.log(`  ❌ ${label}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

async function run() {
  console.log('\n══════════════════════════════════════');
  console.log('  JIRUSite API Smoke Test');
  console.log(`  Target: ${BASE}`);
  console.log('══════════════════════════════════════\n');

  // 1. Health
  console.log('[ Health ]');
  const health = await get('/health'.replace('/api', '').replace('/api', ''));
  // health is on root
  const healthR = await new Promise((resolve, reject) => {
    const req = http.request({ hostname: 'localhost', port: process.env.PORT || 3000, path: '/health', method: 'GET' }, (res) => {
      let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(JSON.parse(d)));
    });
    req.on('error', reject); req.end();
  });
  ok('GET /health', healthR.status === 'ok');

  // 2. Auth — register new user
  console.log('\n[ Auth ]');
  const phone = `+2519${Date.now().toString().slice(-8)}`;
  const regR = await post('/api/auth/register', {
    full_name: 'Smoke Test User', phone_number: phone, password: 'Test1234!', role: 'owner',
  });
  ok('POST /auth/register → 201', regR.status === 201, `got ${regR.status}`);
  ok('Register returns accessToken', !!regR.body.accessToken);
  ok('Register returns user.id', !!regR.body.user?.id);

  // 3. Login with seeded owner
  const loginR = await post('/api/auth/login', { phone_number: '+251911000001', password: 'password123' });
  ok('POST /auth/login → 200', loginR.status === 200, `got ${loginR.status}`);
  ok('Login returns accessToken', !!loginR.body.accessToken);
  const token = loginR.body.accessToken;
  const orgId = loginR.body.user?.organization_id;

  // 4. Token refresh
  const refreshR = await post('/api/auth/refresh', { refreshToken: loginR.body.refreshToken });
  ok('POST /auth/refresh → 200', refreshR.status === 200, `got ${refreshR.status}`);
  ok('Refresh returns new accessToken', !!refreshR.body.accessToken);
  const freshToken = refreshR.body.accessToken;

  // 5. Organization
  console.log('\n[ Organization ]');
  const orgR = await get('/api/organizations/me', freshToken);
  ok('GET /organizations/me → 200', orgR.status === 200, `got ${orgR.status}`);
  ok('Org has name', !!orgR.body.name, orgR.body.name);
  ok('Org has subscription_tier', !!orgR.body.subscription_tier);
  console.log(`     → "${orgR.body.name}" [${orgR.body.subscription_tier}]`);

  const membersR = await get('/api/organizations/me/members', freshToken);
  ok('GET /organizations/me/members → 200', membersR.status === 200);
  ok('Members list has entries', membersR.body.length >= 1);

  // 6. Projects
  console.log('\n[ Projects ]');
  const projectsR = await get('/api/projects', freshToken);
  ok('GET /projects → 200', projectsR.status === 200, `got ${projectsR.status}`);
  ok('Projects returned', projectsR.body.length > 0, `count=${projectsR.body.length}`);
  // Use the project with the most cost codes (Bole Residential, seeded with 8)
  const proj = projectsR.body.find(p => p.name?.includes('Bole')) || projectsR.body[0];
  const projId = proj.id;
  console.log(`     → "${proj.name}" — status=${proj.status} budget=${proj.total_budget} ETB`);

  const projR = await get(`/api/projects/${projId}`, freshToken);
  ok(`GET /projects/:id → 200`, projR.status === 200);

  const dashR = await get(`/api/projects/${projId}/dashboard`, freshToken);
  ok('GET /projects/:id/dashboard → 200', dashR.status === 200);
  ok('Dashboard has budget', dashR.body.budget?.total_budget !== undefined);
  ok(`Dashboard has ${dashR.body.costCodes?.length} cost codes`, dashR.body.costCodes?.length > 0);
  console.log(`     → budget=${dashR.body.budget.total_budget} ETB, costCodes=${dashR.body.costCodes?.length}, expenses=${dashR.body.recentExpenses?.length}`);

  const codesR = await get(`/api/projects/${projId}/cost-codes`, freshToken);
  ok('GET /projects/:id/cost-codes → 200', codesR.status === 200);
  ok('Cost codes returned', codesR.body.length > 0);

  // Create a project
  const newProjR = await post('/api/projects', {
    name: 'Smoke Test Project', total_budget: 5000000, currency: 'ETB', status: 'planning',
  }, freshToken);
  ok('POST /projects → 201', newProjR.status === 201, `got ${newProjR.status} ${JSON.stringify(newProjR.body).substring(0,80)}`);

  // 7. Expenses
  console.log('\n[ Expenses ]');
  const { v4: uuidv4 } = require('uuid');
  const expR = await post(`/api/expenses/project/${projId}`, {
    amount: 75000, expense_type: 'material', transaction_date: '2026-08-06',
    description: 'Smoke test: cement purchase', client_generated_id: uuidv4(),
  }, freshToken);
  ok('POST /expenses/project/:id → 201', expR.status === 201, `got ${expR.status} ${JSON.stringify(expR.body).substring(0,60)}`);
  ok('Expense has id', !!expR.body.id);
  ok('Expense sync_status=synced', expR.body.sync_status === 'synced');
  console.log(`     → id=${expR.body.id?.substring(0,8)}... amount=${expR.body.amount} ETB`);

  const expsR = await get(`/api/expenses/project/${projId}`, freshToken);
  ok('GET /expenses/project/:id → 200', expsR.status === 200);
  ok('Expenses list has entries', expsR.body.length > 0);

  // Sync batch
  const batchR = await post('/api/expenses/sync-batch', {
    expenses: [{
      project_id: projId, amount: 12000, expense_type: 'equipment',
      transaction_date: '2026-08-06', description: 'Generator rental',
      client_generated_id: uuidv4(),
    }]
  }, freshToken);
  ok('POST /expenses/sync-batch → 200', batchR.status === 200);
  ok('Sync batch returned synced item', batchR.body.synced?.length === 1);

  // 8. Labor
  console.log('\n[ Labor ]');
  const labR = await post(`/api/labor/project/${projId}`, {
    worker_or_crew_name: 'Smoke Crew', total_amount: 9000, work_date: '2026-08-06',
    number_of_workers: 20, daily_rate: 450, client_generated_id: uuidv4(),
  }, freshToken);
  ok('POST /labor/project/:id → 201', labR.status === 201, `got ${labR.status}`);
  ok('Labor has total_amount', parseFloat(labR.body.total_amount) === 9000);

  const labListR = await get(`/api/labor/project/${projId}`, freshToken);
  ok('GET /labor/project/:id → 200', labListR.status === 200);

  const labBatchR = await post('/api/labor/sync-batch', {
    entries: [{
      project_id: projId, worker_or_crew_name: 'Batch Crew',
      total_amount: 5400, work_date: '2026-08-06', number_of_workers: 12,
      client_generated_id: uuidv4(),
    }]
  }, freshToken);
  ok('POST /labor/sync-batch → 200', labBatchR.status === 200);

  // 9. Materials
  console.log('\n[ Materials ]');
  const matsR = await get('/api/materials', freshToken);
  ok('GET /materials → 200', matsR.status === 200);
  ok('Materials list populated', matsR.body.length >= 10, `count=${matsR.body.length}`);

  const matId = (matsR.body.find(m => m.name?.includes('Derba')) || matsR.body[0]).id;
  const priceHR = await get(`/api/materials/${matId}/price-history?region=Addis%20Ababa`, freshToken);
  ok('GET /materials/:id/price-history → 200', priceHR.status === 200);

  const submitPriceR = await post('/api/materials/prices', {
    material_id: matId, region: 'Addis Ababa', price: 1275, observed_at: '2026-08-06',
  }, freshToken);
  ok('POST /material-prices → 201', submitPriceR.status === 201, `got ${submitPriceR.status}`);
  console.log(`     → ${matsR.body.length} materials, ${priceHR.body.length} price history entries`);

  // 10. Suppliers
  console.log('\n[ Suppliers ]');
  const supsR = await get('/api/suppliers', freshToken);
  ok('GET /suppliers → 200', supsR.status === 200);
  ok('Suppliers list populated', supsR.body.length >= 5, `count=${supsR.body.length}`);

  const supsFilterR = await get('/api/suppliers?category=cement', freshToken);
  ok('GET /suppliers?category=cement filters', supsFilterR.status === 200);

  const createSupR = await post('/api/suppliers', {
    name: 'Smoke Supplier Ltd', category: 'aggregate', phone_number: '+251900000001',
  }, freshToken);
  ok('POST /suppliers → 201', createSupR.status === 201);

  // 11. Quotes
  console.log('\n[ Quotes ]');
  const qReqR = await post('/api/quote-requests', {
    project_id: projId, material_id: matId, quantity: 100, unit: 'quintal',
    notes: 'Smoke test quote request',
  }, freshToken);
  ok('POST /quote-requests → 201', qReqR.status === 201, `got ${qReqR.status}`);
  const qrId = qReqR.body.id;

  const qListR = await get('/api/quote-requests', freshToken);
  ok('GET /quote-requests → 200', qListR.status === 200);

  const suppId = supsR.body[0].id;
  const qRespR = await post(`/api/quote-requests/${qrId}/responses`, {
    supplier_id: suppId, quoted_price: 1250,
  }, freshToken);
  ok('POST /quote-requests/:id/responses → 201', qRespR.status === 201);

  const qRespListR = await get(`/api/quote-requests/${qrId}/responses`, freshToken);
  ok('GET /quote-requests/:id/responses → 200', qRespListR.status === 200);

  // 12. Purchase Orders
  console.log('\n[ Purchase Orders ]');
  const poR = await post(`/api/purchase-orders/project/${projId}`, {
    supplier_id: suppId,
    items: [{ quantity: 50, unit_price: 1250, material_id: matId }],
    notes: 'Smoke test PO',
  }, freshToken);
  ok('POST /purchase-orders/project/:id → 201', poR.status === 201, `got ${poR.status}`);
  const poId = poR.body.id;

  const poListR = await get(`/api/purchase-orders/project/${projId}`, freshToken);
  ok('GET /purchase-orders/project/:id → 200', poListR.status === 200);
  ok('PO list has entry', poListR.body.length > 0);

  const approveR = await patch(`/api/purchase-orders/${poId}/approve`, { action: 'approve' }, freshToken);
  ok('PATCH /purchase-orders/:id/approve → 200', approveR.status === 200, `got ${approveR.status}`);
  ok('PO status=approved', approveR.body.status === 'approved');

  // 13. Schedule
  console.log('\n[ Schedule ]');
  const taskR = await post(`/api/schedule/project/${projId}`, {
    name: 'Foundation Work', planned_start: '2026-08-01', planned_end: '2026-09-30',
  }, freshToken);
  ok('POST /schedule/project/:id → 201', taskR.status === 201, `got ${taskR.status}`);
  const taskId = taskR.body.id;

  const schedR = await get(`/api/schedule/project/${projId}`, freshToken);
  ok('GET /schedule/project/:id → 200', schedR.status === 200);

  const taskUpdateR = await patch(`/api/schedule-tasks/${taskId}`, { percent_complete: 40, status: 'in_progress' }, freshToken);
  ok('PATCH /schedule-tasks/:id → 200', taskUpdateR.status === 200);
  ok('Task percent_complete updated', taskUpdateR.body.percent_complete === 40);

  // 14. Notifications
  console.log('\n[ Notifications ]');
  const notifsR = await get('/api/notifications', freshToken);
  ok('GET /notifications → 200', notifsR.status === 200);

  const markAllR = await patch('/api/notifications/read-all', {}, freshToken);
  ok('PATCH /notifications/read-all → 200', markAllR.status === 200);

  // 15. Billing
  console.log('\n[ Billing ]');
  const billR = await get('/api/billing/subscription', freshToken);
  ok('GET /billing/subscription → 200', billR.status === 200);
  ok('Subscription has tier', !!billR.body.subscription?.subscription_tier);
  console.log(`     → tier=${billR.body.subscription.subscription_tier} status=${billR.body.subscription.subscription_status}`);

  // ── Summary ────────────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════');
  console.log(`  Results: ${passed} passed, ${failed} failed`);
  if (failed === 0) {
    console.log('  ✅ ALL TESTS PASSED — Backend is fully operational');
  } else {
    console.log('  ⚠️  Some tests failed — check output above');
  }
  console.log('══════════════════════════════════════\n');
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
