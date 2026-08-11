/**
 * Seed script — populates the database with realistic Ethiopian construction data.
 * Run with: node src/db/seed.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const bcrypt = require('bcryptjs');
const { v4: uuid } = require('uuid');
const { query, pool } = require('./pool');

async function seed() {
  console.log('🌱 Seeding database...');

  // ── Organization ──────────────────────────────────────────────────────────
  const orgId = uuid();
  await query(
    `INSERT INTO organizations (id, name, tin_number, subscription_tier, subscription_status, trial_ends_at)
     VALUES ($1, 'Zemen Construction PLC', '0001234567', 'growth', 'active', now() + interval '30 days')
     ON CONFLICT DO NOTHING`,
    [orgId]
  );

  // ── Users ──────────────────────────────────────────────────────────────────
  const ownerHash = await bcrypt.hash('password123', 12);
  const engineerHash = await bcrypt.hash('engineer123', 12);

  const ownerId = uuid();
  const engineerId = uuid();
  const managerId = uuid();

  await query(
    `INSERT INTO users (id, organization_id, full_name, phone_number, email, password_hash, role, preferred_language)
     VALUES
       ($1, $4, 'Abebe Girma', '+251911000001', 'abebe@zemen.com', $5, 'owner', 'am'),
       ($2, $4, 'Tigist Haile', '+251911000002', 'tigist@zemen.com', $6, 'site_engineer', 'am'),
       ($3, $4, 'Dawit Bekele', '+251911000003', 'dawit@zemen.com', $6, 'project_manager', 'am')
     ON CONFLICT (phone_number) DO NOTHING`,
    [ownerId, engineerId, managerId, orgId, ownerHash, engineerHash]
  );

  // ── Projects ───────────────────────────────────────────────────────────────
  const project1Id = uuid();
  const project2Id = uuid();

  await query(
    `INSERT INTO projects
       (id, organization_id, name, location_text, latitude, longitude,
        total_budget, currency, start_date, target_end_date, status, created_by)
     VALUES
       ($1, $3, 'Bole Residential Complex', 'Bole Sub-City, Addis Ababa', 8.9956, 38.7870,
        45000000, 'ETB', '2026-01-15', '2027-06-30', 'active', $4),
       ($2, $3, 'Megenagna Office Tower', 'Yeka Sub-City, Addis Ababa', 9.0227, 38.7896,
        120000000, 'ETB', '2026-03-01', '2028-12-31', 'planning', $4)
     ON CONFLICT DO NOTHING`,
    [project1Id, project2Id, orgId, ownerId]
  );

  // ── Project members ────────────────────────────────────────────────────────
  await query(
    `INSERT INTO project_members (project_id, user_id, role_on_project)
     VALUES
       ($1, $3, 'owner'), ($1, $4, 'site_engineer'), ($1, $5, 'project_manager'),
       ($2, $3, 'owner'), ($2, $5, 'project_manager')
     ON CONFLICT DO NOTHING`,
    [project1Id, project2Id, ownerId, engineerId, managerId]
  );

  // ── Cost codes ─────────────────────────────────────────────────────────────
  const costCodes = [
    { id: uuid(), code: '01', name: 'Site Preparation', budget: 1500000, sort: 1 },
    { id: uuid(), code: '02', name: 'Foundation', budget: 6000000, sort: 2 },
    { id: uuid(), code: '03', name: 'Structure & Rebar', budget: 14000000, sort: 3 },
    { id: uuid(), code: '04', name: 'Masonry & Block Work', budget: 5000000, sort: 4 },
    { id: uuid(), code: '05', name: 'Plastering & Finishing', budget: 4000000, sort: 5 },
    { id: uuid(), code: '06', name: 'Electrical (MEP)', budget: 3500000, sort: 6 },
    { id: uuid(), code: '07', name: 'Plumbing (MEP)', budget: 2500000, sort: 7 },
    { id: uuid(), code: '08', name: 'Labor (General)', budget: 5000000, sort: 8 },
  ];

  for (const cc of costCodes) {
    await query(
      `INSERT INTO cost_codes (id, project_id, code, name, budgeted_amount, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
      [cc.id, project1Id, cc.code, cc.name, cc.budget, cc.sort]
    );
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  const suppliers = [
    { id: uuid(), name: 'Derba Cement PLC',        phone: '+251112345678', location: 'Addis Ababa', category: 'cement',    verified: true },
    { id: uuid(), name: 'Sefer Steel',              phone: '+251912345679', location: 'Addis Ababa', category: 'rebar',     verified: true },
    { id: uuid(), name: 'Sunshine Building Materials', phone: '+251913456780', location: 'Adama',  category: 'aggregate', verified: false },
    { id: uuid(), name: 'Addis Electrical Supply',  phone: '+251914567891', location: 'Addis Ababa', category: 'electrical', verified: true },
    { id: uuid(), name: 'Nile Plumbing & Fittings', phone: '+251915678902', location: 'Hawassa',    category: 'plumbing',  verified: false },
  ];

  for (const s of suppliers) {
    await query(
      `INSERT INTO suppliers (id, name, phone_number, location_text, category, is_verified)
       VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
      [s.id, s.name, s.phone, s.location, s.category, s.verified]
    );
  }

  // ── Materials ──────────────────────────────────────────────────────────────
  const materials = [
    { id: uuid(), name: 'Cement (Derba 50kg)',         category: 'cement',    unit: 'quintal' },
    { id: uuid(), name: 'Cement (Mugher 50kg)',         category: 'cement',    unit: 'quintal' },
    { id: uuid(), name: 'Rebar Ø8 (per quintal)',       category: 'rebar',     unit: 'quintal' },
    { id: uuid(), name: 'Rebar Ø12 (per quintal)',      category: 'rebar',     unit: 'quintal' },
    { id: uuid(), name: 'Crushed Stone (m3)',            category: 'aggregate', unit: 'm3' },
    { id: uuid(), name: 'River Sand (m3)',               category: 'aggregate', unit: 'm3' },
    { id: uuid(), name: 'Hollow Block (40x20x20)',       category: 'masonry',   unit: 'piece' },
    { id: uuid(), name: 'Corrugated Iron Sheet (0.4mm)', category: 'roofing',   unit: 'sheet' },
    { id: uuid(), name: 'Ceramic Floor Tile (60x60)',    category: 'finishing', unit: 'm2' },
    { id: uuid(), name: 'PVC Pipe 4" (6m)',              category: 'plumbing',  unit: 'piece' },
  ];

  for (const mat of materials) {
    await query(
      `INSERT INTO materials (id, name, category, standard_unit)
       VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
      [mat.id, mat.name, mat.category, mat.unit]
    );
  }

  // ── Material prices (Addis Ababa region) ──────────────────────────────────
  const cementMat = materials[0];
  const rebarMat  = materials[2];

  await query(
    `INSERT INTO material_prices (material_id, supplier_id, region, price, source, reported_by, observed_at)
     VALUES
       ($1, $3, 'Addis Ababa', 1250, 'verified_supplier', $5, CURRENT_DATE),
       ($1, $3, 'Addis Ababa', 1220, 'verified_supplier', $5, CURRENT_DATE - 30),
       ($2, $4, 'Addis Ababa', 8500, 'verified_supplier', $5, CURRENT_DATE),
       ($2, $4, 'Addis Ababa', 8200, 'verified_supplier', $5, CURRENT_DATE - 30)
     ON CONFLICT DO NOTHING`,
    [cementMat.id, rebarMat.id, suppliers[0].id, suppliers[1].id, ownerId]
  );

  // ── Sample expenses ────────────────────────────────────────────────────────
  const expenseData = [
    { type: 'material', desc: 'Cement purchase - 50 quintals', amount: 62500, cc: costCodes[1] },
    { type: 'material', desc: 'Rebar Ø12 - 20 quintals',       amount: 170000, cc: costCodes[2] },
    { type: 'labor',    desc: 'Foundation excavation crew',     amount: 45000, cc: costCodes[1] },
    { type: 'equipment',desc: 'Concrete mixer rental',          amount: 18000, cc: costCodes[2] },
    { type: 'material', desc: 'Crushed stone - 30m3',           amount: 36000, cc: costCodes[1] },
  ];

  for (const e of expenseData) {
    await query(
      `INSERT INTO expenses
         (project_id, cost_code_id, entered_by, description, amount, expense_type,
          transaction_date, sync_status, client_generated_id)
       VALUES ($1,$2,$3,$4,$5,$6, CURRENT_DATE - (random()*30)::int, 'synced', gen_random_uuid())
       ON CONFLICT DO NOTHING`,
      [project1Id, e.cc.id, engineerId, e.desc, e.amount, e.type]
    );
  }

  // ── Sample labor entries ───────────────────────────────────────────────────
  await query(
    `INSERT INTO labor_entries
       (project_id, cost_code_id, entered_by, worker_or_crew_name, work_description,
        number_of_workers, daily_rate, total_amount, work_date, sync_status, client_generated_id)
     VALUES
       ($1, $2, $3, 'Rebar Crew (Gebru & team)', 'Rebar installation foundation',
        8, 450, 3600, CURRENT_DATE - 2, 'synced', gen_random_uuid()),
       ($1, $2, $3, 'Masonry Workers',            'Block laying ground floor',
        12, 400, 4800, CURRENT_DATE - 1, 'synced', gen_random_uuid())
     ON CONFLICT DO NOTHING`,
    [project1Id, costCodes[2].id, engineerId]
  );

  console.log('✅ Seed complete!');
  console.log('');
  console.log('Test accounts:');
  console.log('  Owner:    +251911000001 / password123');
  console.log('  Engineer: +251911000002 / engineer123');
  console.log('  Manager:  +251911000003 / engineer123');

  await pool.end();
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
