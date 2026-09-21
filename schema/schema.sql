-- ============================================================
-- Automated Ward Staffing System — Schema
-- ============================================================

CREATE TABLE wards (
    ward_id INTEGER PRIMARY KEY,
    ward_name TEXT NOT NULL,
    unit_type TEXT NOT NULL,
    capacity INTEGER NOT NULL
);

CREATE TABLE staff (
    staff_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL,
    ward_id INTEGER NOT NULL,
    hire_date TEXT NOT NULL,
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

CREATE TABLE staffing_requirements (
    ward_id INTEGER NOT NULL,
    shift_type TEXT NOT NULL,
    min_staff_required INTEGER NOT NULL,
    PRIMARY KEY (ward_id, shift_type),
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

CREATE TABLE shifts (
    shift_id INTEGER PRIMARY KEY,
    staff_id INTEGER NOT NULL,
    ward_id INTEGER NOT NULL,
    shift_date TEXT NOT NULL,
    shift_type TEXT NOT NULL,
    hours_worked REAL NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

CREATE TABLE patients (
    patient_id INTEGER PRIMARY KEY,
    age INTEGER NOT NULL,
    risk_level TEXT NOT NULL
);

CREATE TABLE admissions (
    admission_id INTEGER PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    ward_id INTEGER NOT NULL,
    admission_date TEXT NOT NULL,
    discharge_date TEXT,
    readmission_flag INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

CREATE TABLE incidents (
    incident_id INTEGER PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    ward_id INTEGER NOT NULL,
    incident_date TEXT NOT NULL,
    severity TEXT NOT NULL,
    incident_type TEXT NOT NULL,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
);

-- Automation output tables — populated by triggers, never by hand
CREATE TABLE staffing_alerts (
    alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ward_id INTEGER NOT NULL,
    shift_date TEXT NOT NULL,
    shift_type TEXT NOT NULL,
    staff_count INTEGER NOT NULL,
    required_count INTEGER NOT NULL,
    flagged_at TEXT NOT NULL
);

CREATE TABLE readmission_alerts (
    alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    admission_id INTEGER NOT NULL,
    days_since_last_discharge INTEGER NOT NULL,
    flagged_at TEXT NOT NULL
);