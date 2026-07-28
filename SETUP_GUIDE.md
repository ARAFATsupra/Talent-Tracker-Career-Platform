# Talent Tracker AI — Complete Setup Guide

This takes you from "I have this zip file" to a running app on your
laptop with a real Firebase database behind it, signed in as a real
demo user. Follow the steps **in order** — each one depends on the
previous.

Total time: roughly 45–60 minutes the first time (mostly tool installs
and waiting for Firebase to provision things).

---

## Step 0 — What you need installed first

| Tool | Version | Check with | Get it from |
|---|---|---|---|
| Flutter SDK | 3.19+ | `flutter --version` | https://flutter.dev/docs/get-started/install |
| Android Studio (or just Android SDK + an emulator/device) | 2023.2+ | — | https://developer.android.com/studio |
| Node.js | 18.x LTS | `node --version` | https://nodejs.org |
| Firebase CLI | latest | `firebase --version` | `npm install -g firebase-tools` |
| Git (optional, only if you want version control) | latest | `git --version` | https://git-scm.com |

After installing Flutter, run:

```bash
flutter doctor
```

Fix any ❌ items before continuing — most commonly it'll ask you to
accept Android licenses (`flutter doctor --android-licenses`) or
install a missing component.

---

## Step 1 — Unzip the project

Unzip `talent_tracker_ai_phase9.zip` anywhere on your machine, e.g.:

```bash
cd ~/Projects   # or wherever you keep code
unzip talent_tracker_ai_phase9.zip
cd talent_tracker_ai
```

You should see folders like `lib/`, `test/`, `functions/`, `scripts/`,
and files like `pubspec.yaml`, `firebase.json`, `firestore.rules`.

---

## Step 2 — Install Flutter dependencies

```bash
flutter pub get
```

This downloads every package listed in `pubspec.yaml` (Riverpod,
go_router, Firebase SDKs, etc.). If this fails, it's almost always a
Flutter/Dart version mismatch — re-check `flutter --version` against
the `sdk: '>=3.3.0 <4.0.0'` line in `pubspec.yaml`.

At this point **don't run the app yet** — it'll fail, because there's
no real Firebase project wired up. That's Step 3–5.

---

## Step 3 — Create your Firebase project

1. Go to https://console.firebase.google.com → **Add project**.
   Name it anything, e.g. `talent-tracker-ai-dev`. You can disable
   Google Analytics for a dev project if asked — doesn't matter either
   way.
2. Once the project is created, turn on the 3 services this app uses:
   - **Build → Authentication** → "Get started" → **Sign-in method**
     tab → enable **Email/Password**.
   - **Build → Firestore Database** → "Create database" → start in
     **production mode** → pick a region close to you (e.g.
     `asia-south1` / Mumbai if you're in Bangladesh — lowest latency
     per Section 16.3 of the spec).
   - **Build → Storage** → "Get started" → same region as Firestore.

That's it for console clicking — everything else happens from your
terminal.

---

## Step 4 — Connect the Flutter app to your Firebase project

This step generates `lib/firebase_options.dart` with your project's
real API keys (the one in the zip is a placeholder that will fail to
connect on purpose).

```bash
# one-time global install
dart pub global activate flutterfire_cli

# from the project root (talent_tracker_ai/)
flutterfire configure
```

It'll ask you to:
1. Pick the Firebase project you just created.
2. Pick which platforms to configure — choose **android** (and
   **ios**/**web** too if you plan to run on those).
3. Confirm/enter an Android package name — any reverse-domain string
   works, e.g. `com.diu.talenttrackerai`.

When it finishes, `lib/firebase_options.dart` is overwritten with real
values, and `android/app/google-services.json` is created
automatically. **Don't hand-edit either of these files.**

---

## Step 5 — Deploy the security rules, indexes, and Cloud Functions

These protect your database (Section 9.5's access matrix) and run the
AI matching logic server-side (Section 14.1). Do this **before**
seeding data or running the app, so nothing hits an empty rule set.

```bash
# Log in to Firebase (opens a browser window once)
firebase login

# Link this folder to your Firebase project
firebase use --add
# → pick the project you created in Step 3

# Install the Cloud Functions dependencies and build them
cd functions
npm install
npm run build
cd ..

# Deploy everything: Firestore rules, indexes, Storage rules, Functions
firebase deploy
```

This can take a few minutes the first time (Cloud Functions cold-start
deployment is the slow part). If it fails on Functions specifically
with a billing-related error: Cloud Functions requires the **Blaze
(pay-as-you-go)** plan, not the free Spark plan — Firebase will show you
a link to upgrade. The free tier's usage allowance is generous enough
that a dev project like this won't actually cost anything in practice.

If you only want Firestore rules/indexes without functions for now:

```bash
firebase deploy --only firestore,storage
```

You can deploy functions later once you're ready.

---

## Step 6 — Seed the database with demo data

This populates Firestore with the spec's Section 10 demo accounts (10
students + 1 recruiter + 1 admin), all 10 job descriptions, and one
full student transcript (Rahim Ahmed) so you have something real to
sign in and test with immediately.

1. **Get a service account key** (lets the seed script write to your
   database directly, bypassing the app's normal sign-in flow):
   - Firebase Console → ⚙️ **Project Settings** → **Service Accounts**
     tab → **Generate new private key** → confirm.
   - This downloads a `.json` file. Rename it (or just move it) to:
     ```
     talent_tracker_ai/scripts/service-account.json
     ```
   - This file is already gitignored — never commit it or share it
     publicly, it grants full admin access to your database.

2. **Run the seed script**:

```bash
cd scripts
npm install
npm run seed
```

You should see output like:

```
Seeding users...
  - Created Auth user rahim@diu.edu.bd (xK2pLm...)
  ...
Seeded 12 user accounts.

Seeding job descriptions...
  - jd_DA_001 (Junior Data Analyst)
  ...
Seeded 10 job descriptions.

Seeding Rahim Ahmed's full transcript (Section 10.2)...
  - Wrote 8 semesters, recalculated CGPA = 3.88
✅ Done. Demo password for every account: TalentTracker123!
```

Every demo account's password is `TalentTracker123!` (see
`scripts/seed.js` to change it before running, or just change it later
from inside the app via Profile Settings).

**Only Rahim Ahmed has full grade data seeded.** The other 9 students
exist as accounts but have no `semesters` yet — see the comment block
at the bottom of `scripts/seed.js` for how to add the rest from
Section 10.3–10.11 of the spec, or just type them in by hand later
through Grade Entry (S-09) once signed in as that student.

Safe to re-run — it updates rather than duplicates if you run it again.

---

## Step 7 — Run the app

```bash
# from the project root, talent_tracker_ai/
flutter run
```

Pick a connected device or emulator if prompted. You should land on:
**Splash → Onboarding (first run only) → Login screen.**

### Try it out

Sign in as the verified demo profile:

- **Email:** `rahim@diu.edu.bd`
- **Password:** `TalentTracker123!`

From the Student Dashboard:
1. Tap **AI Job Match** → you should see **Junior Business Analyst at
   58.8%** — this exactly matches Section 12.3's worked example and
   `test/services/ai/match_engine_test.dart`'s UT-03, so if you see
   this number, the whole AI engine pipeline (Firestore → grades →
   scoring → UI) is working correctly end to end.
2. Tap into that role → **Job Role Detail** (S-12) → see the full
   course-by-course breakdown.
3. Tap **Skill Gap Roadmap** → see the Gantt chart of what's left to
   close the gap on that role.

Then try the other two roles:
- **Recruiter:** `karim.placement@diu.edu.bd` / `TalentTracker123!`
  → Job Search → search "Business Analyst" → Rahim should appear in
  the ranked shortlist.
- **Admin:** `shahidul.admin@diu.edu.bd` / `TalentTracker123!`
  → JD Library, User Management, AI Weighting Config, etc.

---

## Troubleshooting

| Problem | Likely cause |
|---|---|
| `flutter run` fails with an API key / Firebase error | Step 4 (`flutterfire configure`) wasn't run, or it ran before Step 3's services were enabled. Re-run it. |
| Sign-in works but every screen shows "permission denied" | `firestore.rules` wasn't deployed (Step 5), or was deployed to the wrong project. Check `firebase use` shows your project. |
| AI Job Match shows "no job roles" for every student | `jobDescriptions` wasn't seeded (Step 6), or rules weren't deployed. |
| Seed script errors immediately | Check `scripts/service-account.json` exists and is valid JSON — re-download it from Firebase Console if unsure. |
| `firebase deploy` fails on functions specifically | Needs the Blaze (pay-as-you-go) billing plan — see Step 5's note. You can skip functions for now with `firebase deploy --only firestore,storage`. |
| `npm install` fails inside `functions/` or `scripts/` | Check `node --version` is 18.x — older/newer major versions can have native-module build issues with `firebase-admin`. |

---

## Where to go from here

- **`PHASE1_GUIDE.md` through `PHASE9_GUIDE.md`** — one per development
  phase, each documenting what was built, how to test it, and any
  spec discrepancies or simplifications made along the way (search for
  🔶 in each one).
- **`functions/` README context** is in `PHASE6_GUIDE.md` — Cloud
  Functions architecture, how the TypeScript AI engine mirrors the
  Dart one, and what still needs an email provider connected.
- Known remaining gaps (not blockers, just refinements) are listed at
  the bottom of `PHASE9_GUIDE.md`.

If anything in this guide doesn't match what actually happens on your
machine, that's useful signal — note the exact error and we can fix
either the guide or the underlying code.
