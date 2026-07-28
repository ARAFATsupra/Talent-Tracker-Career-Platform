# Deploying Talent Tracker AI on Streamlit Community Cloud

## Files needed in your GitHub repo

```
streamlit_app.py
requirements.txt
```

That's it — no other files needed.

---

## Step 1 — Firebase Service Account

The app uses **Firebase Admin SDK** which needs a service account key
(not the web API key). Generate one:

1. Go to [Firebase Console](https://console.firebase.google.com/) →
   Project **talent-tracker-ai-dev** → Project Settings → Service Accounts.
2. Click **Generate new private key** → download the JSON file.

> Keep this file secret — never commit it to GitHub.

---

## Step 2 — Add secrets to Streamlit Cloud

On [share.streamlit.io](https://share.streamlit.io), open your app →
**Settings → Secrets** and paste the service account JSON like this:

```toml
[firebase_credentials]
type = "service_account"
project_id = "talent-tracker-ai-dev"
private_key_id = "YOUR_PRIVATE_KEY_ID"
private_key = "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n"
client_email = "firebase-adminsdk-xxxx@talent-tracker-ai-dev.iam.gserviceaccount.com"
client_id = "YOUR_CLIENT_ID"
auth_uri = "https://accounts.google.com/o/oauth2/auth"
token_uri = "https://oauth2.googleapis.com/token"
auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
client_x509_cert_url = "https://www.googleapis.com/robot/v1/metadata/x509/..."
universe_domain = "googleapis.com"
```

Copy every field from the downloaded JSON exactly.

---

## Step 3 — Deploy

1. Push `streamlit_app.py` and `requirements.txt` to a GitHub repo.
2. Go to [share.streamlit.io](https://share.streamlit.io) → **New app**.
3. Connect your GitHub repo, set **Main file path** to `streamlit_app.py`.
4. Click **Deploy**.

---

## Local development

```bash
pip install streamlit firebase-admin pandas

# Put your service account JSON as serviceAccount.json in the project root,
# OR set the environment variable:
export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json

streamlit run streamlit_app.py
```

---

## What the app covers

| Role | Screens |
|------|---------|
| Student | Dashboard, Grade Entry, AI Job Match (top 3), Skill Gap Roadmap, Progress Tracker |
| Recruiter | Dashboard, Job Search & Candidate Ranking, Shortlist CSV export |
| Admin | Dashboard, User Management, JD Library (add/archive), Course Master, System Logs |

The AI matching engine is a pure Python port of `lib/services/ai/match_engine.dart`
(Section 12.2 weighted formula, Section 12.4 gap detection, Section 12.5 roadmap,
Section 12.6 recruiter scan). It reads from and writes to the same Firestore
collections as the Flutter app.
