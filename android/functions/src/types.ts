/**
 * Firestore document shapes — mirrors Section 9.2-9.5 and the Dart
 * models in lib/models/. Cloud Functions read/write these directly via
 * the Admin SDK (which bypasses firestore.rules), so keeping these types
 * in sync with the Dart side matters for correctness, not security.
 */

export interface CourseGrade {
  courseCode: string;
  courseName: string;
  creditHours: number;
  grade: string; // '' = not taken yet (Section 9.3)
  gradePoint: number;
  isCoreCourse: boolean;
}

export interface Semester {
  semesterNumber: number;
  semesterName: string;
  isComplete: boolean;
  semesterGPA: number;
  courses: CourseGrade[];
}

export interface UserDoc {
  fullName: string;
  email: string;
  role: "student" | "recruiter" | "admin";
  studentId: string;
  department: string;
  batch: string;
  profilePhotoUrl?: string | null;
  cgpa: number;
  isActive: boolean;
  preferredLanguage: string;
  failedLoginCount: number;
  isLocked: boolean;
}

export interface JobDescription {
  title: string;
  category: string;
  requiredSkills: string[];
  criticalPathCourses: string[];
  courseWeights: Record<string, number>;
  salaryRangeBDT: { min: number; max: number };
  sourceUrl: string;
  certifications: string[];
  remediations?: Record<string, string>; // 🔶 same extension as JDModel.remediations (Dart)
  isActive: boolean;
  addedBy: string;
}

/** Section 9.5 — written by Cloud Functions ONLY. */
export interface MatchResult {
  jdId: string;
  jobTitle: string;
  matchPercentage: number;
  missingSkills: string[];
  missingCourses: string[];
  confidenceFlag: "empty" | "partial" | "full";
  computedAt: FirebaseFirestore.FieldValue;
}

export interface Placement {
  recruiterUid: string;
  studentUid: string;
  studentName: string;
  jobTitle: string;
  matchPercentage: number;
  status: "shortlisted" | "contacted" | "interviewScheduled" | "placed" | "rejected";
  notes: string;
}

export type LogSeverity = "ERROR" | "WARNING" | "INFO";

export interface SystemLog {
  severity: LogSeverity;
  message: string;
  source: string;
  resolved: boolean;
  occurredAt: FirebaseFirestore.FieldValue;
}
