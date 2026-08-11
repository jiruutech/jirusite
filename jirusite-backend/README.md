# JIRUSite Backend — Node.js + Express API

PERN stack API shared by both the Flutter mobile app and the web client.

## Tech Stack

- **Runtime:** Node.js 18+
- **Framework:** Express 4
- **Database:** PostgreSQL 15+ via `pg` pool
- **Migrations:** `node-pg-migrate`
- **Auth:** JWT access + refresh tokens (15min / 7day)
- **OTP:** 6-digit HMAC-backed codes, 5min TTL
- **File uploads:** `multer` (local disk for MVP, swap to S3 in prod)
- **Push:** Firebase Admin SDK (FCM)
- **SMS:** AfroMessage / Geez SMS stub (configure `SMS_API_URL` + `SMS_API_TOKEN`)
- **Payments:** Telebirr API stub (configure in `billing.routes.js`)

## Setup

```bash
npm install
cp .env.example .env   # fill in your values
npm run migrate:up     # run all migrations
npm run seed           # optional: load sample Ethiopian construction data
npm run dev            # nodemon watch mode
```

## Environment Variables

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Access token signing key |
| `JWT_REFRESH_SECRET` | Refresh token signing key |
| `OTP_SECRET` | HMAC seed for OTP generation |
| `SMS_API_URL` | AfroMessage / Geez SMS endpoint |
| `SMS_API_TOKEN` | SMS gateway bearer token |
| `SMS_SENDER_ID` | Sender name shown on SMS |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to Firebase service account JSON |
| `TELEBIRR_APP_ID` | Telebirr app ID |
| `TELEBIRR_APP_KEY` | Telebirr signing key |
| `TELEBIRR_SHORT_CODE` | Telebirr merchant short code |
| `TELEBIRR_NOTIFY_URL` | Webhook URL for Telebirr callbacks |
| `S3_ENDPOINT` / `S3_BUCKET` | S3-compatible storage (production) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins |

## API Endpoints

### Auth
| Method | Path | Description |
|---|---|---|
| POST | `/api/auth/register` | Register with phone + password |
| POST | `/api/auth/login` | Login → JWT pair |
| POST | `/api/auth/refresh` | Rotate refresh token |
| POST | `/api/auth/otp/request` | Send OTP via SMS |
| POST | `/api/auth/otp/verify` | Verify OTP |
| POST | `/api/auth/logout` | Revoke all refresh tokens |

### Organizations
| Method | Path | Description |
|---|---|---|
| GET | `/api/organizations/me` | Current org details |
| POST | `/api/organizations` | Create org (owner onboarding) |
| PATCH | `/api/organizations/me` | Update org name/TIN |
| GET | `/api/organizations/me/members` | List team |
| POST | `/api/organizations/me/members` | Invite by phone number |

### Projects
| Method | Path | Description |
|---|---|---|
| GET | `/api/projects` | List all org projects with budget health |
| POST | `/api/projects` | Create project |
| GET | `/api/projects/:id` | Project detail |
| PATCH | `/api/projects/:id` | Update project |
| GET | `/api/projects/:id/dashboard` | Budget vs actual summary |
| GET/POST | `/api/projects/:id/cost-codes` | Cost code phases |
| GET/POST | `/api/projects/:id/team` | Project members |

### Expenses
| Method | Path | Description |
|---|---|---|
| GET | `/api/expenses/project/:projectId` | Filtered expense list |
| POST | `/api/expenses/project/:projectId` | Create expense |
| POST | `/api/expenses/sync-batch` | **Offline sync batch upsert** |
| POST | `/api/expenses/:id/receipt` | Upload receipt photo |
| DELETE | `/api/expenses/:id` | Soft delete |

### Labor
| Method | Path | Description |
|---|---|---|
| GET | `/api/labor/project/:projectId` | Labor entry list |
| POST | `/api/labor/project/:projectId` | Create labor entry |
| POST | `/api/labor/sync-batch` | **Offline sync batch upsert** |
| DELETE | `/api/labor/:id` | Soft delete |

### Materials & Prices
| Method | Path | Description |
|---|---|---|
| GET | `/api/materials` | Materials list (searchable) |
| GET | `/api/materials/:id` | Material detail |
| GET | `/api/materials/:id/price-history` | Price time series |
| POST | `/api/materials/prices` | Submit crowdsourced price |

### Suppliers
| Method | Path | Description |
|---|---|---|
| GET | `/api/suppliers` | List/filter by category + region |
| GET | `/api/suppliers/:id` | Supplier detail |
| POST | `/api/suppliers` | Add supplier |

### Quotes
| Method | Path | Description |
|---|---|---|
| POST | `/api/quote-requests` | Create quote request |
| GET | `/api/quote-requests` | List org quote requests |
| GET | `/api/quote-requests/:id/responses` | Quote responses |
| POST | `/api/quote-requests/:id/responses` | Add supplier response |

### Purchase Orders
| Method | Path | Description |
|---|---|---|
| GET | `/api/purchase-orders/project/:id` | POs for project |
| POST | `/api/purchase-orders/project/:id` | Create PO |
| PATCH | `/api/purchase-orders/:id/approve` | Approve / reject |
| DELETE | `/api/purchase-orders/:id` | Soft delete |

### Schedule
| Method | Path | Description |
|---|---|---|
| GET | `/api/schedule/project/:id` | Task list (grouped by cost code) |
| POST | `/api/schedule/project/:id` | Create task |
| PATCH | `/api/schedule-tasks/:id` | Update progress / status |
| DELETE | `/api/schedule-tasks/:id` | Delete task |

### Notifications
| Method | Path | Description |
|---|---|---|
| GET | `/api/notifications` | In-app notification list |
| PATCH | `/api/notifications/:id/read` | Mark single as read |
| PATCH | `/api/notifications/read-all` | Mark all as read |
| POST | `/api/notifications/register-token` | Register FCM device token |

### Billing
| Method | Path | Description |
|---|---|---|
| GET | `/api/billing/subscription` | Current plan + payment history |
| POST | `/api/billing/telebirr/initiate` | Initiate Telebirr payment |
| POST | `/api/billing/telebirr/webhook` | Telebirr payment callback |

## Security

- JWT verified on every protected route via `authenticate` middleware
- Organization scoping enforced server-side — `project_id` always validated against requesting user's `organization_id`
- Role-based authorization: `owner`/`admin` can approve POs; `site_engineer` can create expenses/labor; `viewer` is read-only
- Soft deletes on `expenses`, `labor_entries`, `purchase_orders` — financial records never hard-deleted
- Audit log written on every create/update/delete/approve action

## Offline Sync Design

The `client_generated_id` (UUID created on-device) is the idempotency key.
`POST /api/expenses/sync-batch` and `POST /api/labor/sync-batch` use `ON CONFLICT (client_generated_id) DO UPDATE` — retried syncs are safe.
Conflicts (server version newer than client) are recorded in `sync_conflicts` and returned to the mobile client.
