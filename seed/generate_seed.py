"""
Generates synthetic (fake) seed data for the Automated Ward
Staffing System. No real patient or staff data is used anywhere
in this project — all names and records are randomly generated.
"""
import random
import sqlite3
from datetime import date, timedelta

random.seed(42)  # fixed seed = reproducible data every time you rebuild

DB_PATH = "ward_system.db"
START_DATE = date(2025, 1, 1)
END_DATE = date(2025, 6, 30)

FIRST_NAMES = ["James","Sarah","Mohammed","Emily","David","Priya","Tom","Aisha","Chris","Grace",
               "Liam","Olivia","Noah","Sophie","Daniel","Ruth","Kevin","Fatima","Ben","Laura"]
LAST_NAMES = ["Smith","Johnson","Williams","Brown","Jones","Khan","Taylor","Davies","Wilson","Evans",
              "Thomas","Roberts","Walker","White","Edwards","Green","Hall","Wood","Clarke","Patel"]
ROLES = ["Support Worker","Staff Nurse","Senior Support Worker","Ward Manager","OT Assistant"]
INCIDENT_TYPES = ["Self-harm","Aggression","Absconding","Falls","Verbal altercation","Property damage"]
SEVERITIES = ["Low","Medium","High"]
RISK_LEVELS = ["Low","Medium","High"]

def random_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def build():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Order matters: schema first, then triggers, THEN data —
    # so the triggers fire as data is inserted.
    cur.executescript(open("schema/schema.sql").read())
    cur.executescript(open("automation/triggers.sql").read())

    # --- Wards ---
    wards = [
        (1, "Mulberry Ward", "CAMHS", 12),
        (2, "Willow Ward", "CAMHS", 10),
        (3, "Cedar Ward", "Adult Acute", 18),
        (4, "Ashford Unit", "Low Secure Forensic", 15),
        (5, "Birchwood Ward", "CAMHS", 8),
    ]
    cur.executemany("INSERT INTO wards VALUES (?,?,?,?)", wards)

    # --- Staffing requirements (min staff per ward per shift type) ---
    reqs = []
    for w in wards:
        reqs.append((w[0], "Day", max(3, w[3] // 3)))
        reqs.append((w[0], "Night", max(2, w[3] // 5)))
    cur.executemany("INSERT INTO staffing_requirements VALUES (?,?,?)", reqs)

    # --- Staff ---
    staff = []
    sid = 1
    for w in wards:
        n_staff = random.randint(10, 16)
        for _ in range(n_staff):
            name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
            role = random.choice(ROLES)
            hire = random_date(date(2022,1,1), date(2025,1,1)).isoformat()
            staff.append((sid, name, role, w[0], hire))
            sid += 1
    cur.executemany("INSERT INTO staff VALUES (?,?,?,?,?)", staff)

    # --- Shifts (deliberately understaff ~12% of the time, to prove the trigger works) ---
    shift_id = 1
    day = START_DATE
    while day <= END_DATE:
        for w in wards:
            ward_staff = [s for s in staff if s[3] == w[0]]
            for shift_type in ["Day", "Night"]:
                required = next(r[2] for r in reqs if r[0] == w[0] and r[1] == shift_type)
                if random.random() < 0.12:
                    n_on_shift = max(0, required - random.randint(1, 2))
                else:
                    n_on_shift = required + random.randint(0, 2)
                chosen = random.sample(ward_staff, min(n_on_shift, len(ward_staff)))
                hours = 12.5 if shift_type == "Day" else 11.5
                for s in chosen:
                    cur.execute(
                        "INSERT INTO shifts VALUES (?,?,?,?,?,?)",
                        (shift_id, s[0], w[0], day.isoformat(), shift_type, hours)
                    )
                    shift_id += 1
        day += timedelta(days=7)  # one sample day per week keeps volume realistic but manageable

    # --- Patients ---
    patients = []
    for pid in range(1, 301):
        age = random.randint(12, 17) if random.random() < 0.5 else random.randint(18, 65)
        risk = random.choices(RISK_LEVELS, weights=[0.4, 0.4, 0.2])[0]
        patients.append((pid, age, risk))
    cur.executemany("INSERT INTO patients VALUES (?,?,?)", patients)

    # --- Admissions (some deliberately readmitted within 30 days, to prove that trigger works too) ---
    admission_id = 1
    admissions_plain = []
    patient_last_discharge = {}
    for _ in range(450):
        patient = random.choice(patients)
        ward = random.choice(wards)
        if patient[0] in patient_last_discharge and random.random() < 0.3:
            last_discharge = patient_last_discharge[patient[0]]
            admit = last_discharge + timedelta(days=random.randint(1, 29))
        else:
            admit = random_date(START_DATE, END_DATE)
        stay_len = random.randint(3, 60)
        discharge = admit + timedelta(days=stay_len)
        discharge_str = None if discharge > END_DATE else discharge.isoformat()
        if discharge_str:
            patient_last_discharge[patient[0]] = discharge
        admissions_plain.append((admission_id, patient[0], ward[0], admit.isoformat(), discharge_str))
        admission_id += 1

    # Insert in date order so the readmission trigger sees prior history correctly
    admissions_plain.sort(key=lambda r: r[3])
    for a in admissions_plain:
        cur.execute(
            "INSERT INTO admissions (admission_id, patient_id, ward_id, admission_date, discharge_date) VALUES (?,?,?,?,?)",
            a
        )

    # --- Incidents ---
    incident_id = 1
    for _ in range(180):
        patient = random.choice(patients)
        ward = random.choice(wards)
        cur.execute(
            "INSERT INTO incidents VALUES (?,?,?,?,?,?)",
            (incident_id, patient[0], ward[0],
             random_date(START_DATE, END_DATE).isoformat(),
             random.choices(SEVERITIES, weights=[0.5, 0.35, 0.15])[0],
             random.choice(INCIDENT_TYPES))
        )
        incident_id += 1

    conn.commit()
    conn.close()
    print("Database built successfully: ward_system.db")

if __name__ == "__main__":
    build()