# JIRUSite — Construction Cost Tracking Platform

Ethiopian construction project and materials cost-tracking platform.

## Monorepo Structure

```
JIRUSite/
├── jirusite-backend/    Node.js + Express API (PERN stack)
└── jirusite-mobile/     Flutter mobile app (Android + iOS)
```

---

## Quick Start

### 1. Backend

**Prerequisites:** PostgreSQL 15+, Node.js 18+

```bash
cd jirusite-backend

# Install dependencies
npm install

# Copy and configure environment
cp .env.example .env
# Edit .env — set DATABASE_URL, JWT_SECRET, etc.

# Run migrations
npm run migrate:up

# Seed with sample data (optional)
npm run seed

# Start development server
npm run dev
```

Server runs on `http://localhost:3000`

### 2. Flutter App

**Prerequisites:** Flutter 3.38+, Android Studio / Xcode

```bash
cd jirusite-mobile

# Install dependencies
flutter pub get

# Run on Android emulator or connected device
flutter run

# Run tests
flutter test
```

---

## Architecture

See `jirusite-backend/README.md` and `jirusite-mobile/README.md` for detailed docs.
