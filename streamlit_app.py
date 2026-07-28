"""
Talent Tracker AI — Streamlit Web App
Connects to the same Firebase project as the Flutter app.
Firebase project: talent-tracker-ai-dev

Deploy on Streamlit Community Cloud:
1. Push this file + requirements.txt to a GitHub repo.
2. Add Firebase credentials to Streamlit secrets (see DEPLOY.md).
3. Connect the repo on share.streamlit.io.
"""

import streamlit as st
import firebase_admin
from firebase_admin import credentials, auth, firestore
import json
import os
import math
from datetime import datetime

# ──────────────────────────────────────────────────
# Firebase initialisation (runs once per session)
# ──────────────────────────────────────────────────

GRADE_POINTS = {
    "A+": 4.00, "A": 3.75, "A-": 3.625,
    "B+": 3.50, "B": 3.25, "B-": 2.875,
    "C+": 2.50, "C": 2.25, "D": 1.00, "F": 0.00,
}
VALID_GRADES = list(GRADE_POINTS.keys())
TOTAL_SEMESTERS = 8
RECRUITER_SCAN_WEIGHT_THRESHOLD = 0.20
MIN_PASSING_GRADE_POINT = 2.0

APP_COLORS = {
    "primary": "#1565C0",
    "teal": "#00796B",
    "success": "#2E7D32",
    "warning": "#E65100",
    "error": "#B71C1C",
}


@st.cache_resource
def init_firebase():
    """Initialise Firebase Admin SDK once per process."""
    if firebase_admin._apps:
        return firestore.client()

    cred_dict = None

    # -- Option 1a: TOML table [firebase_credentials] in Streamlit secrets --
    # Paste this in Settings -> Secrets on Streamlit Cloud:
    #
    #   [firebase_credentials]
    #   type = "service_account"
    #   project_id = "talent-tracker-ai-dev"
    #   private_key_id = "..."
    #   private_key = "-----BEGIN RSA PRIVATE KEY-----\nMIIE...\n-----END RSA PRIVATE KEY-----\n"
    #   client_email = "firebase-adminsdk-...@....iam.gserviceaccount.com"
    #   client_id = "..."
    #   auth_uri = "https://accounts.google.com/o/oauth2/auth"
    #   token_uri = "https://oauth2.googleapis.com/token"
    #   auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
    #   client_x509_cert_url = "https://www.googleapis.com/..."
    #   universe_domain = "googleapis.com"
    #
    if "firebase_credentials" in st.secrets:
        raw = st.secrets["firebase_credentials"]
        if isinstance(raw, str):
            # Option 1b: user pasted the whole JSON as one string value
            cred_dict = json.loads(raw)
        else:
            # Normal TOML table -- iterate key/value pairs
            cred_dict = {k: v for k, v in raw.items()}

    # -- Option 2: whole JSON blob under key FIREBASE_KEY ----------------
    # FIREBASE_KEY = '{ "type": "service_account", ... }'
    elif "FIREBASE_KEY" in st.secrets:
        cred_dict = json.loads(st.secrets["FIREBASE_KEY"])

    # -- Option 3: local service-account JSON file (local dev) -----------
    else:
        sa_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccount.json")
        if os.path.exists(sa_path):
            with open(sa_path, encoding="utf-8") as f:
                cred_dict = json.load(f)

    if cred_dict is None:
        found_keys = list(st.secrets.keys()) if hasattr(st, "secrets") else []
        st.error(
            "**Firebase credentials not found.**\n\n"
            f"Secret keys the app can see: `{found_keys}`\n\n"
            "Expected one of:\n"
            "- TOML table `[firebase_credentials]` with all service-account fields\n"
            "- `firebase_credentials = \'<JSON string>\'`\n"
            "- `FIREBASE_KEY = \'<JSON string>\'`\n\n"
            "See **DEPLOY.md** for the exact format."
        )
        st.stop()

    # private_key may arrive with literal backslash-n instead of real newlines
    if "private_key" in cred_dict:
        cred_dict["private_key"] = cred_dict["private_key"].replace("\\n", "\n")

    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred)
    return firestore.client()

db = init_firebase()

# ──────────────────────────────────────────────────
# Page config
# ──────────────────────────────────────────────────

st.set_page_config(
    page_title="Talent Tracker AI",
    page_icon="🎯",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    f"""
    <style>
    .stApp {{ background-color: #F5F7FA; }}
    .block-container {{ padding-top: 1.5rem; }}
    h1, h2, h3 {{ color: {APP_COLORS["primary"]}; }}
    .metric-card {{
        background: white;
        border-radius: 10px;
        padding: 1rem 1.2rem;
        box-shadow: 0 1px 4px rgba(0,0,0,.08);
        margin-bottom: .8rem;
    }}
    .badge-green {{
        background: {APP_COLORS["success"]}22;
        color: {APP_COLORS["success"]};
        padding: 2px 8px;
        border-radius: 12px;
        font-size: .78rem;
        font-weight: 600;
    }}
    .badge-red {{
        background: {APP_COLORS["error"]}22;
        color: {APP_COLORS["error"]};
        padding: 2px 8px;
        border-radius: 12px;
        font-size: .78rem;
        font-weight: 600;
    }}
    .badge-amber {{
        background: {APP_COLORS["warning"]}22;
        color: {APP_COLORS["warning"]};
        padding: 2px 8px;
        border-radius: 12px;
        font-size: .78rem;
        font-weight: 600;
    }}
    </style>
    """,
    unsafe_allow_html=True,
)

# ──────────────────────────────────────────────────
# Session state defaults
# ──────────────────────────────────────────────────

if "uid" not in st.session_state:
    st.session_state.uid = None
if "role" not in st.session_state:
    st.session_state.role = None
if "user_doc" not in st.session_state:
    st.session_state.user_doc = {}

# ──────────────────────────────────────────────────
# Firestore helpers
# ──────────────────────────────────────────────────


def get_user(uid: str) -> dict:
    doc = db.collection("users").document(uid).get()
    return doc.to_dict() or {} if doc.exists else {}


def get_semesters(uid: str) -> list[dict]:
    docs = (
        db.collection("users")
        .document(uid)
        .collection("semesters")
        .order_by("semesterNumber")
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def get_active_jds() -> list[dict]:
    docs = (
        db.collection("jobDescriptions")
        .where("isActive", "==", True)
        .stream()
    )
    return [{"jdId": d.id, **d.to_dict()} for d in docs]


def get_all_students() -> list[dict]:
    docs = db.collection("users").where("role", "==", "student").stream()
    return [{"uid": d.id, **d.to_dict()} for d in docs]


def get_student_courses(uid: str) -> list[dict]:
    """Flatten all semesters into a list of course-grade dicts."""
    semesters = get_semesters(uid)
    courses = []
    for sem in semesters:
        for c in sem.get("courses", []):
            courses.append({
                "courseCode": c.get("courseCode", ""),
                "courseName": c.get("courseName", ""),
                "grade": c.get("grade", ""),
                "gradePoint": GRADE_POINTS.get(c.get("grade", ""), 0.0),
                "semesterNumber": sem.get("semesterNumber", 0),
            })
    return courses


def compute_cgpa(courses: list[dict]) -> float:
    graded = [c for c in courses if c.get("grade") and c["grade"] != "F"]
    if not graded:
        return 0.0
    return round(sum(c["gradePoint"] for c in graded) / len(graded), 2)


# ──────────────────────────────────────────────────
# AI Match Engine (Section 12 — pure Python port)
# ──────────────────────────────────────────────────


def calculate_match_score(student_courses: list[dict], jd: dict) -> dict:
    """Section 12.2 — weighted alignment score."""
    by_code = {c["courseCode"]: c for c in student_courses}
    total_earned = 0.0
    total_possible = 0.0
    breakdown = []

    for code in jd.get("criticalPathCourses", []):
        weight = jd.get("courseWeights", {}).get(code, 0.0)
        if weight <= 0:
            continue
        sc = by_code.get(code)
        has_grade = sc and sc.get("grade")
        gp = GRADE_POINTS.get(sc["grade"], 0.0) if has_grade else 0.0
        contribution = gp * weight
        total_earned += contribution
        total_possible += 4.0 * weight
        breakdown.append({
            "courseCode": code,
            "courseName": sc["courseName"] if sc else code,
            "gradePoint": gp,
            "weight": weight,
            "contribution": contribution,
            "hasTaken": bool(has_grade),
        })

    percentage = (total_earned / total_possible * 100) if total_possible > 0 else 0.0
    return {"matchPercentage": round(percentage, 1), "breakdown": breakdown}


def detect_gaps(student_courses: list[dict], jd: dict) -> list[dict]:
    """Section 12.4 — three gap types."""
    by_code = {c["courseCode"]: c for c in student_courses}
    gaps = []
    passed_names = {
        c["courseName"].lower()
        for c in student_courses
        if GRADE_POINTS.get(c.get("grade", ""), 0.0) >= MIN_PASSING_GRADE_POINT
    }

    for code in jd.get("criticalPathCourses", []):
        weight = jd.get("courseWeights", {}).get(code, 0.0)
        sc = by_code.get(code)
        if sc is None or not sc.get("grade"):
            gaps.append({
                "type": "notTaken",
                "courseCode": code,
                "courseName": code,
                "weight": weight,
                "remediation": jd.get("remediations", {}).get(
                    code,
                    f"Enrol in {code}. " + (
                        f"Suggested: {jd['certifications'][0]}"
                        if jd.get("certifications") else ""
                    ),
                ),
            })
        elif GRADE_POINTS.get(sc["grade"], 0.0) < MIN_PASSING_GRADE_POINT:
            gaps.append({
                "type": "lowGrade",
                "courseCode": code,
                "courseName": sc["courseName"],
                "weight": weight,
                "remediation": jd.get("remediations", {}).get(
                    code,
                    f"Re-take or improve {sc['courseName']}. " + (
                        f"Suggested: {jd['certifications'][0]}"
                        if jd.get("certifications") else ""
                    ),
                ),
            })

    for skill in jd.get("requiredSkills", []):
        if skill.lower() not in passed_names:
            gaps.append({
                "type": "missingSkill",
                "skillName": skill,
                "weight": 0.0,
                "remediation": jd.get("remediations", {}).get(
                    skill,
                    f"Build skill in {skill}. " + (
                        f"Suggested: {jd['certifications'][0]}"
                        if jd.get("certifications") else ""
                    ),
                ),
            })

    return gaps


def top3_evaluations(student_courses: list[dict], jds: list[dict]) -> list[dict]:
    results = []
    for jd in jds:
        score = calculate_match_score(student_courses, jd)
        gaps = detect_gaps(student_courses, jd)
        results.append({"jd": jd, "score": score, "gaps": gaps})
    results.sort(key=lambda r: r["score"]["matchPercentage"], reverse=True)
    return results[:3]


def rank_for_recruiter(students_with_courses: list[dict], jd: dict) -> list[dict]:
    """Section 12.6 — recruiter scan with weight threshold filter."""
    kept_codes = [
        c for c in jd.get("criticalPathCourses", [])
        if jd.get("courseWeights", {}).get(c, 0.0) >= RECRUITER_SCAN_WEIGHT_THRESHOLD
    ]
    kept_weights = {
        k: v for k, v in jd.get("courseWeights", {}).items()
        if v >= RECRUITER_SCAN_WEIGHT_THRESHOLD
    }
    scan_jd = {**jd, "criticalPathCourses": kept_codes, "courseWeights": kept_weights}

    summaries = []
    for s in students_with_courses:
        result = calculate_match_score(s["courses"], scan_jd)
        summaries.append({
            "uid": s["uid"],
            "fullName": s.get("fullName", "—"),
            "studentId": s.get("studentId", "—"),
            "cgpa": s.get("cgpa", 0.0),
            "matchPercentage": result["matchPercentage"],
        })

    summaries.sort(
        key=lambda x: (x["matchPercentage"], x["cgpa"]),
        reverse=True,
    )
    return summaries


# ──────────────────────────────────────────────────
# Auth: sign-in via Firebase REST API
# (Admin SDK doesn't support password sign-in)
# ──────────────────────────────────────────────────

FIREBASE_WEB_API_KEY = "AIzaSyChG67j2FRUrCDOut7wflD2nkJ32rF3Qek"


def sign_in_with_password(email: str, password: str) -> dict:
    import urllib.request, urllib.error

    url = (
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
        f"?key={FIREBASE_WEB_API_KEY}"
    )
    payload = json.dumps(
        {"email": email, "password": password, "returnSecureToken": True}
    ).encode()
    req = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = json.loads(e.read())
        return {"error": body.get("error", {}).get("message", "Unknown error")}


# ──────────────────────────────────────────────────
# UI helpers
# ──────────────────────────────────────────────────

def score_color(pct: float) -> str:
    if pct >= 70:
        return APP_COLORS["success"]
    if pct >= 45:
        return APP_COLORS["warning"]
    return APP_COLORS["error"]


def donut_svg(pct: float, size: int = 80) -> str:
    r = size * 0.38
    cx = cy = size / 2
    circ = 2 * math.pi * r
    filled = circ * pct / 100
    color = score_color(pct)
    return f"""
    <svg width="{size}" height="{size}" viewBox="0 0 {size} {size}">
      <circle cx="{cx}" cy="{cy}" r="{r}" fill="none"
              stroke="#E0E0E0" stroke-width="{size*0.12}"/>
      <circle cx="{cx}" cy="{cy}" r="{r}" fill="none"
              stroke="{color}" stroke-width="{size*0.12}"
              stroke-dasharray="{filled:.1f} {circ:.1f}"
              stroke-linecap="round"
              transform="rotate(-90 {cx} {cy})"/>
      <text x="{cx}" y="{cy+size*0.07}" text-anchor="middle"
            font-size="{size*0.2}" font-weight="700" fill="{color}">
        {pct:.0f}%
      </text>
    </svg>
    """


# ──────────────────────────────────────────────────
# Screens
# ──────────────────────────────────────────────────

def screen_login():
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown(
            f"<h2 style='text-align:center;color:{APP_COLORS['primary']};'>"
            "🎯 Talent Tracker AI</h2>",
            unsafe_allow_html=True,
        )
        st.markdown(
            "<p style='text-align:center;color:#757575;'>Career Roadmap Platform · DIU ITM</p>",
            unsafe_allow_html=True,
        )
        st.divider()
        with st.form("login_form"):
            email = st.text_input("Email", placeholder="you@diu.edu.bd")
            password = st.text_input("Password", type="password")
            submitted = st.form_submit_button(
                "Sign In", use_container_width=True, type="primary"
            )

        if submitted:
            if not email or not password:
                st.error("Enter both email and password.")
                return
            with st.spinner("Signing in…"):
                result = sign_in_with_password(email, password)
            if "error" in result:
                msg = result["error"]
                if "INVALID_LOGIN_CREDENTIALS" in msg or "EMAIL_NOT_FOUND" in msg:
                    st.error("Invalid email or password.")
                elif "USER_DISABLED" in msg:
                    st.error("This account has been disabled by the admin.")
                else:
                    st.error(f"Sign-in failed: {msg}")
                return

            uid = result["localId"]
            user_doc = get_user(uid)
            if not user_doc:
                st.error("Account not found in the database.")
                return
            if not user_doc.get("isActive", True):
                st.error("Your account is inactive. Contact the admin.")
                return

            st.session_state.uid = uid
            st.session_state.role = user_doc.get("role", "student")
            st.session_state.user_doc = user_doc
            st.rerun()


# ── Student portal ──────────────────────────────


def screen_student():
    uid = st.session_state.uid
    user = st.session_state.user_doc

    st.sidebar.title(f"👋 {user.get('fullName', 'Student')}")
    st.sidebar.caption(f"ID: {user.get('studentId', '—')}  |  Batch: {user.get('batch', '—')}")
    page = st.sidebar.radio(
        "Navigate",
        ["Dashboard", "Grade Entry", "AI Job Match", "Skill Gap Roadmap", "Progress Tracker"],
    )
    if st.sidebar.button("Sign Out", use_container_width=True):
        for k in ["uid", "role", "user_doc"]:
            st.session_state[k] = None if k != "user_doc" else {}
        st.rerun()

    courses = get_student_courses(uid)
    cgpa = compute_cgpa(courses)

    # ── Dashboard ──
    if page == "Dashboard":
        st.title("Student Dashboard")
        c1, c2, c3 = st.columns(3)
        c1.metric("CGPA", f"{cgpa:.2f} / 4.00")
        c2.metric("Courses Entered", len(courses))
        c3.metric("Department", user.get("department", "—"))

        st.divider()
        if courses:
            st.subheader("Quick AI Match Preview")
            jds = get_active_jds()
            if jds:
                top3 = top3_evaluations(courses, jds)
                cols = st.columns(min(3, len(top3)))
                for i, ev in enumerate(top3):
                    with cols[i]:
                        pct = ev["score"]["matchPercentage"]
                        st.markdown(donut_svg(pct, size=100), unsafe_allow_html=True)
                        st.markdown(
                            f"**{ev['jd']['title']}**  \n"
                            f"<span style='color:#757575;font-size:.8rem;'>"
                            f"{ev['jd'].get('category','')}</span>",
                            unsafe_allow_html=True,
                        )
            else:
                st.info("No job roles in the library yet.")
        else:
            st.info("Enter your semester grades to see AI match results.")

    # ── Grade Entry ──
    elif page == "Grade Entry":
        st.title("Grade Entry")
        semesters = get_semesters(uid)

        sem_num = st.selectbox("Semester", list(range(1, TOTAL_SEMESTERS + 1)))
        existing = next(
            (s for s in semesters if s.get("semesterNumber") == sem_num), None
        )
        existing_courses = existing.get("courses", []) if existing else []

        with st.expander(f"Semester {sem_num} Grades", expanded=True):
            st.caption("Add courses and their grades. Save when done.")
            num_courses = st.number_input(
                "Number of courses", min_value=1, max_value=10,
                value=max(len(existing_courses), 1), key=f"nc_{sem_num}"
            )
            new_courses = []
            for i in range(int(num_courses)):
                ec = existing_courses[i] if i < len(existing_courses) else {}
                col_code, col_name, col_grade = st.columns([1.5, 2.5, 1])
                code = col_code.text_input(
                    "Code", value=ec.get("courseCode", ""),
                    key=f"code_{sem_num}_{i}"
                )
                name = col_name.text_input(
                    "Course Name", value=ec.get("courseName", ""),
                    key=f"name_{sem_num}_{i}"
                )
                default_idx = (
                    VALID_GRADES.index(ec["grade"])
                    if ec.get("grade") in VALID_GRADES else 0
                )
                grade = col_grade.selectbox(
                    "Grade", VALID_GRADES, index=default_idx,
                    key=f"grade_{sem_num}_{i}"
                )
                if code.strip():
                    new_courses.append({
                        "courseCode": code.strip().upper(),
                        "courseName": name.strip(),
                        "grade": grade,
                        "gradePoint": GRADE_POINTS[grade],
                    })

            if st.button("Save Semester", type="primary"):
                sem_data = {
                    "semesterNumber": sem_num,
                    "courses": new_courses,
                    "updatedAt": datetime.utcnow(),
                }
                ref = db.collection("users").document(uid).collection("semesters")
                if existing:
                    ref.document(existing["id"]).set(sem_data, merge=True)
                else:
                    ref.add(sem_data)

                # Recompute & persist CGPA
                all_courses = get_student_courses(uid)
                new_cgpa = compute_cgpa(all_courses)
                db.collection("users").document(uid).update({"cgpa": new_cgpa})
                st.session_state.user_doc["cgpa"] = new_cgpa
                st.success(f"Semester {sem_num} saved. Updated CGPA: {new_cgpa:.2f}")
                st.rerun()

        if courses:
            st.subheader("All entered grades")
            import pandas as pd
            df = pd.DataFrame(courses)[
                ["semesterNumber", "courseCode", "courseName", "grade", "gradePoint"]
            ].rename(columns={
                "semesterNumber": "Sem", "courseCode": "Code",
                "courseName": "Course", "grade": "Grade", "gradePoint": "GP",
            })
            st.dataframe(df, use_container_width=True, hide_index=True)

    # ── AI Job Match ──
    elif page == "AI Job Match":
        st.title("AI Job Match")
        st.caption(
            "Weighted alignment of your grades against job-description critical paths (Section 12.2)."
        )
        if not courses:
            st.warning("Enter your semester grades first.")
            return
        jds = get_active_jds()
        if not jds:
            st.info("No job roles in the library yet. Ask the admin to add some.")
            return

        top3 = top3_evaluations(courses, jds)
        for ev in top3:
            jd = ev["jd"]
            pct = ev["score"]["matchPercentage"]
            gaps = ev["gaps"]
            color = score_color(pct)

            with st.container():
                col_donut, col_info = st.columns([1, 4])
                with col_donut:
                    st.markdown(donut_svg(pct, size=110), unsafe_allow_html=True)
                with col_info:
                    st.markdown(
                        f"### {jd['title']}"
                        f"<span style='margin-left:8px;font-size:.85rem;"
                        f"color:#757575;'>{jd.get('category','')}</span>",
                        unsafe_allow_html=True,
                    )
                    sal_min = jd.get("salaryMinBDT", 0)
                    sal_max = jd.get("salaryMaxBDT", 0)
                    if sal_min or sal_max:
                        st.caption(
                            f"Salary range: ৳{sal_min:,} – ৳{sal_max:,} BDT/month"
                        )
                    if jd.get("sourceUrl"):
                        st.markdown(f"[View JD ↗]({jd['sourceUrl']})")

                    matched = [
                        b for b in ev["score"]["breakdown"] if b["hasTaken"]
                    ]
                    missing = [b for b in ev["score"]["breakdown"] if not b["hasTaken"]]

                    if matched:
                        st.markdown(
                            " ".join(
                                f"<span class='badge-green'>✓ {b['courseCode']}</span>"
                                for b in matched
                            ),
                            unsafe_allow_html=True,
                        )
                    if missing:
                        st.markdown(
                            " ".join(
                                f"<span class='badge-red'>✗ {b['courseCode']}</span>"
                                for b in missing
                            ),
                            unsafe_allow_html=True,
                        )

                if gaps:
                    with st.expander(f"Skill Gaps ({len(gaps)})"):
                        for g in gaps:
                            icon = "📌" if g["type"] == "notTaken" else (
                                "📉" if g["type"] == "lowGrade" else "🔧"
                            )
                            label = (
                                g.get("courseName") or g.get("skillName") or g.get("courseCode", "")
                            )
                            st.markdown(f"**{icon} {label}** — {g['remediation']}")
                else:
                    st.success("No gaps detected for this role!")
            st.divider()

    # ── Skill Gap Roadmap ──
    elif page == "Skill Gap Roadmap":
        st.title("Skill Gap Roadmap")
        if not courses:
            st.warning("Enter your semester grades first.")
            return
        jds = get_active_jds()
        if not jds:
            st.info("No job roles in the library yet.")
            return

        jd_titles = {j["jdId"]: j["title"] for j in jds}
        selected_id = st.selectbox(
            "Select a job role",
            list(jd_titles.keys()),
            format_func=lambda x: jd_titles[x],
        )
        jd = next(j for j in jds if j["jdId"] == selected_id)
        gaps = detect_gaps(courses, jd)

        current_sem = max((c["semesterNumber"] for c in courses), default=1)
        remaining = TOTAL_SEMESTERS - current_sem

        if not gaps:
            st.success("No gaps detected — you are fully aligned with this role!")
            return

        sorted_gaps = sorted(gaps, key=lambda g: g["weight"], reverse=True)
        st.subheader(f"Roadmap for: {jd['title']}")
        st.caption(
            f"Current semester: {current_sem} · Remaining: {remaining}  "
            f"(Section 12.5 — highest-weight gaps placed in nearest semesters)"
        )

        import pandas as pd
        rows = []
        for i, gap in enumerate(sorted_gaps):
            offset = min(i, remaining - 1) if remaining > 0 else 0
            target_sem = current_sem + 1 + offset
            label = gap.get("courseName") or gap.get("skillName") or gap.get("courseCode", "")
            rows.append({
                "Target Semester": f"Sem {target_sem}",
                "Gap": label,
                "Type": gap["type"].replace("notTaken", "Not Taken")
                                   .replace("lowGrade", "Low Grade")
                                   .replace("missingSkill", "Missing Skill"),
                "Remediation": gap["remediation"],
            })
        st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

    # ── Progress Tracker ──
    elif page == "Progress Tracker":
        st.title("Progress Tracker")
        if not courses:
            st.warning("Enter your semester grades first.")
            return

        import pandas as pd
        semesters = get_semesters(uid)
        sem_cgpa = []
        for sem in semesters:
            cs = sem.get("courses", [])
            graded = [c for c in cs if c.get("grade") and c["grade"] != "F"]
            avg = (
                sum(GRADE_POINTS.get(c["grade"], 0) for c in graded) / len(graded)
                if graded else 0
            )
            sem_cgpa.append({"Semester": sem.get("semesterNumber"), "Avg GP": round(avg, 2)})

        if sem_cgpa:
            df = pd.DataFrame(sem_cgpa).set_index("Semester")
            st.line_chart(df)

        c1, c2 = st.columns(2)
        c1.metric("Current CGPA", f"{cgpa:.2f}")
        c2.metric("Total Courses", len(courses))

        dist = {}
        for c in courses:
            dist[c["grade"]] = dist.get(c["grade"], 0) + 1
        st.subheader("Grade Distribution")
        st.bar_chart(dist)


# ── Recruiter portal ──────────────────────────


def screen_recruiter():
    user = st.session_state.user_doc
    st.sidebar.title(f"🔍 {user.get('fullName', 'Recruiter')}")
    page = st.sidebar.radio("Navigate", ["Dashboard", "Job Search & Rank", "Shortlist"])
    if st.sidebar.button("Sign Out", use_container_width=True):
        for k in ["uid", "role", "user_doc"]:
            st.session_state[k] = None if k != "user_doc" else {}
        st.rerun()

    jds = get_active_jds()

    if page == "Dashboard":
        st.title("Recruiter Dashboard")
        c1, c2 = st.columns(2)
        c1.metric("Active Job Roles", len(jds))
        students = get_all_students()
        c2.metric("Total Students", len(students))
        st.info("Use 'Job Search & Rank' to see ranked candidates for any role.")

    elif page == "Job Search & Rank":
        st.title("Job Search & Candidate Ranking")
        st.caption("Section 12.6 — low-weight courses excluded from recruiter scan.")
        if not jds:
            st.info("No active job descriptions.")
            return

        jd_map = {j["jdId"]: j["title"] for j in jds}
        sel_id = st.selectbox(
            "Select a job role", list(jd_map.keys()), format_func=lambda x: jd_map[x]
        )
        jd = next(j for j in jds if j["jdId"] == sel_id)

        with st.expander("Job Description Details"):
            st.markdown(f"**Category:** {jd.get('category','—')}")
            st.markdown(f"**Required skills:** {', '.join(jd.get('requiredSkills',[]) or ['—'])}")
            st.markdown(
                f"**Salary:** ৳{jd.get('salaryMinBDT',0):,} – ৳{jd.get('salaryMaxBDT',0):,} BDT/month"
            )
            if jd.get("sourceUrl"):
                st.markdown(f"[View JD ↗]({jd['sourceUrl']})")

        if st.button("Rank Candidates", type="primary"):
            with st.spinner("Running AI match scan…"):
                students = get_all_students()
                profiles = []
                for s in students:
                    s_courses = get_student_courses(s["uid"])
                    profiles.append({**s, "courses": s_courses})
                ranked = rank_for_recruiter(profiles, jd)

            import pandas as pd
            if not ranked:
                st.info("No students in the system yet.")
            else:
                df = pd.DataFrame(ranked)[
                    ["fullName", "studentId", "matchPercentage", "cgpa"]
                ].rename(columns={
                    "fullName": "Name", "studentId": "Student ID",
                    "matchPercentage": "Match %", "cgpa": "CGPA",
                })
                st.dataframe(df, use_container_width=True, hide_index=True)
                st.download_button(
                    "Download CSV",
                    df.to_csv(index=False).encode(),
                    f"shortlist_{sel_id}.csv",
                    "text/csv",
                )

    elif page == "Shortlist":
        st.title("Shortlist")
        st.info(
            "Run a ranking from 'Job Search & Rank', then download the CSV. "
            "Full pipeline board (kanban) is in the Flutter mobile app."
        )


# ── Admin portal ──────────────────────────────


def screen_admin():
    user = st.session_state.user_doc
    st.sidebar.title(f"⚙️ {user.get('fullName', 'Admin')}")
    page = st.sidebar.radio(
        "Navigate",
        ["Dashboard", "User Management", "JD Library", "Course Master", "System Logs"],
    )
    if st.sidebar.button("Sign Out", use_container_width=True):
        for k in ["uid", "role", "user_doc"]:
            st.session_state[k] = None if k != "user_doc" else {}
        st.rerun()

    if page == "Dashboard":
        st.title("Admin Dashboard")
        students = db.collection("users").where("role", "==", "student").stream()
        s_list = list(students)
        recruiters = db.collection("users").where("role", "==", "recruiter").stream()
        jds = get_active_jds()
        c1, c2, c3 = st.columns(3)
        c1.metric("Students", len(s_list))
        c2.metric("Recruiters", len(list(recruiters)))
        c3.metric("Active JDs", len(jds))

    elif page == "User Management":
        st.title("User Management")
        role_filter = st.selectbox("Filter by role", ["all", "student", "recruiter", "admin"])
        query = db.collection("users")
        if role_filter != "all":
            query = query.where("role", "==", role_filter)
        docs = query.stream()
        users = [{"uid": d.id, **d.to_dict()} for d in docs]

        import pandas as pd
        if users:
            df = pd.DataFrame(users)[
                ["fullName", "email", "role", "studentId", "batch", "cgpa", "isActive"]
            ].rename(columns={
                "fullName": "Name", "email": "Email", "role": "Role",
                "studentId": "Student ID", "batch": "Batch",
                "cgpa": "CGPA", "isActive": "Active",
            })
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No users found.")

        st.divider()
        st.subheader("Toggle Account Status")
        uid_input = st.text_input("User UID")
        new_status = st.toggle("Set Active", value=True)
        if st.button("Apply"):
            if uid_input:
                db.collection("users").document(uid_input).update({"isActive": new_status})
                st.success(f"User {uid_input} set to {'active' if new_status else 'inactive'}.")

    elif page == "JD Library":
        st.title("Job Description Library")
        jds = get_active_jds()
        st.caption(f"{len(jds)} active job descriptions")

        for jd in jds:
            with st.expander(f"{jd['title']} ({jd.get('category','')})"):
                st.markdown(f"**Required Skills:** {', '.join(jd.get('requiredSkills',[]))}")
                st.markdown(
                    f"**Critical Path Courses:** {', '.join(jd.get('criticalPathCourses',[]))}"
                )
                weights = jd.get("courseWeights", {})
                if weights:
                    import pandas as pd
                    st.dataframe(
                        pd.DataFrame(
                            [{"Course": k, "Weight": v} for k, v in weights.items()]
                        ),
                        hide_index=True,
                    )
                st.markdown(
                    f"**Salary:** ৳{jd.get('salaryMinBDT',0):,} – ৳{jd.get('salaryMaxBDT',0):,}"
                )
                if st.button(f"Archive {jd['jdId']}", key=f"arch_{jd['jdId']}"):
                    db.collection("jobDescriptions").document(jd["jdId"]).update(
                        {"isActive": False}
                    )
                    st.success("Archived.")
                    st.rerun()

        st.divider()
        st.subheader("Add New Job Description")
        with st.form("add_jd"):
            title = st.text_input("Title")
            category = st.text_input("Category")
            skills = st.text_input("Required Skills (comma-separated)")
            critical = st.text_input("Critical Path Course Codes (comma-separated)")
            weights_raw = st.text_input(
                "Course Weights JSON (e.g. {\"CSE101\": 0.8})", value="{}"
            )
            sal_min = st.number_input("Salary Min (BDT)", value=0, step=1000)
            sal_max = st.number_input("Salary Max (BDT)", value=0, step=1000)
            source_url = st.text_input("Source URL")
            certs = st.text_input("Certifications (comma-separated)")
            submitted = st.form_submit_button("Add JD", type="primary")

        if submitted:
            try:
                weights_dict = json.loads(weights_raw)
            except json.JSONDecodeError:
                st.error("Invalid JSON for course weights.")
                return
            doc = {
                "title": title,
                "category": category,
                "requiredSkills": [s.strip() for s in skills.split(",") if s.strip()],
                "criticalPathCourses": [c.strip() for c in critical.split(",") if c.strip()],
                "courseWeights": {k: float(v) for k, v in weights_dict.items()},
                "salaryRangeBDT": {"min": int(sal_min), "max": int(sal_max)},
                "sourceUrl": source_url,
                "certifications": [c.strip() for c in certs.split(",") if c.strip()],
                "remediations": {},
                "isActive": True,
                "addedBy": st.session_state.uid,
                "createdAt": datetime.utcnow(),
            }
            db.collection("jobDescriptions").add(doc)
            st.success(f"Job description '{title}' added.")
            st.rerun()

    elif page == "Course Master":
        st.title("Course Master")
        docs = db.collection("courses").stream()
        courses = [{"id": d.id, **d.to_dict()} for d in docs]
        import pandas as pd
        if courses:
            df = pd.DataFrame(courses)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No courses in the master list.")

    elif page == "System Logs":
        st.title("System Error Logs")
        docs = (
            db.collection("systemLogs")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(50)
            .stream()
        )
        logs = [d.to_dict() for d in docs]
        if logs:
            import pandas as pd
            st.dataframe(pd.DataFrame(logs), use_container_width=True, hide_index=True)
        else:
            st.info("No logs found.")


# ──────────────────────────────────────────────────
# Main router
# ──────────────────────────────────────────────────

if not st.session_state.uid:
    screen_login()
elif st.session_state.role == "student":
    screen_student()
elif st.session_state.role == "recruiter":
    screen_recruiter()
elif st.session_state.role == "admin":
    screen_admin()
else:
    st.error("Unknown role. Contact admin.")
