# JIRUSite Mobile — Flutter App

Offline-first construction cost tracking for Android and iOS, targeting the Ethiopian market.

## Tech Stack

| Concern | Library |
|---|---|
| State management | `flutter_riverpod` 2.x |
| Navigation | `go_router` 14.x |
| Networking | `dio` 5.x |
| Local database | `sqflite` (raw SQL, no codegen) |
| Offline sync | Custom `SyncEngine` (see `lib/core/sync/`) |
| Connectivity | `connectivity_plus` |
| Secure storage | `flutter_secure_storage` |
| Camera / compress | `image_picker` + `flutter_image_compress` |
| Push notifications | `firebase_messaging` |
| Charts | `fl_chart` |
| Localization | ARB files — en, am, om, ti |

## Running

```bash
flutter pub get
flutter run                    # Android emulator or device
flutter run -d ios             # iOS simulator

flutter test                   # all unit tests
flutter analyze                # static analysis (zero issues)
```

## Folder Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart               MaterialApp.router + localization
│   ├── router.dart            GoRouter — all routes, auth redirect
│   └── theme.dart             AppColors, AppTheme (light + dark)
├── core/
│   ├── database/
│   │   └── app_database.dart  sqflite wrapper, model classes, schema DDL
│   ├── localization/          ARB files + LocaleNotifier
│   ├── network/
│   │   ├── dio_client.dart    Auth interceptor + token refresh
│   │   ├── api_endpoints.dart All endpoint constants
│   │   └── connectivity_service.dart
│   ├── sync/
│   │   └── sync_engine.dart   Offline push/pull orchestrator
│   └── utils/
│       └── currency.dart      formatEtb() — always explicit ETB
└── features/
    ├── auth/                  Login, Register, OTP, OrgSetup, Language
    ├── dashboard/             Project list with budget health indicators
    ├── projects/              Project list + detail + budget chart
    ├── expenses/              Expense list + entry (offline-first write)
    ├── labor/                 Labor entry + list
    ├── materials_pricing/     Materials search + price history chart
    ├── suppliers/             Directory + call/SMS deep links
    ├── purchase_orders/       PO list + create + approve/reject
    ├── schedule/              Task list with percent-complete slider
    ├── notifications/         FCM push + in-app list
    ├── billing/               Telebirr subscription flow
    └── settings/              Language picker, profile, logout
```

## Offline-First Architecture

Every write (expense, labor) goes to the **local sqflite database first** with `sync_status = 'pending'`.

`SyncEngine` triggers on:
1. App foreground
2. Connectivity restored (via `connectivity_plus` stream listener)
3. Periodic timer (every 5 minutes while app is open)

On each sync cycle:
1. Push pending expenses → `POST /api/expenses/sync-batch`
2. Push pending labor → `POST /api/labor/sync-batch`
3. Pull updated projects from server → upsert local DB
4. Update `last_synced_at` timestamp

**Conflict policy:** Server wins. Conflicting rows are marked `sync_status = 'conflict'` locally so nothing is silently lost.

**Photo uploads** are queued separately via `local_photo_queue` table with exponential backoff on failure.

## Localization

Supported languages:
- `en` — English (complete)
- `am` — Amharic / አማርኛ (complete)
- `om` — Afaan Oromo (partial — expand as needed)
- `ti` — Tigrinya / ትግርኛ (partial — expand as needed)

All user-facing strings go through `AppLocalizations`. Numbers/currency formatted as `125,000 ETB` via `formatEtb()`.

> **Note:** Ethiopian calendar support is deferred for MVP. The app uses Gregorian calendar throughout.

## Testing

```bash
flutter test
```

18 unit tests covering:
- Expense insert, sync, conflict marking
- Labor insert, sync
- Project upsert + org-scoping
- Sync metadata read/write
- Photo queue and retry backoff

All tests use `sqflite_common_ffi` in-memory database — no device required.

## Security Notes

- JWT stored via `flutter_secure_storage` (never SharedPreferences)
- Role-based UI gating (e.g., approve buttons hidden from `site_engineer`) — server enforces the same rules independently
- Certificate pinning: configured in `dio_client.dart` for production builds (add your cert hash)

## Firebase Setup

1. Create a Firebase project, add Android + iOS apps
2. Download `google-services.json` → `android/app/`
3. Download `GoogleService-Info.plist` → `ios/Runner/`
4. Run `flutterfire configure` if using FlutterFire CLI

Without Firebase, push notifications are silently disabled — the rest of the app works normally.
