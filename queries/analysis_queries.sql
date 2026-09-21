-- ============================================================
-- ANALYSIS QUERIES
-- Each answers a real operational question a ward manager or
-- clinical governance team would ask.
-- ============================================================

-- 1. Which wards have been understaffed most often?
SELECT w.ward_name, COUNT(*) AS understaffed_shifts
FROM staffing_alerts sa
JOIN wards w ON w.ward_id = sa.ward_id
GROUP BY w.ward_name
ORDER BY understaffed_shifts DESC;

-- 2. Average length of stay per ward
SELECT w.ward_name,
       ROUND(AVG(julianday(a.discharge_date) - julianday(a.admission_date)), 1) AS avg_length_of_stay_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_date IS NOT NULL
GROUP BY w.ward_name
ORDER BY avg_length_of_stay_days DESC;

-- 3. Readmission rate per ward (%)
SELECT w.ward_name,
       COUNT(*) AS total_admissions,
       SUM(a.readmission_flag) AS readmissions,
       ROUND(100.0 * SUM(a.readmission_flag) / COUNT(*), 1) AS readmission_rate_pct
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
GROUP BY w.ward_name
ORDER BY readmission_rate_pct DESC;

-- 4. Monthly incident trend, by severity (CTE)
WITH monthly AS (
    SELECT strftime('%Y-%m', incident_date) AS month,
           severity,
           COUNT(*) AS incident_count
    FROM incidents
    GROUP BY month, severity
)
SELECT * FROM monthly ORDER BY month, severity;

-- 5. Staff ranked by total hours worked, within their own ward (window function)
SELECT s.full_name, w.ward_name,
       SUM(sh.hours_worked) AS total_hours,
       RANK() OVER (PARTITION BY w.ward_id ORDER BY SUM(sh.hours_worked) DESC) AS ward_rank
FROM shifts sh
JOIN staff s ON s.staff_id = sh.staff_id
JOIN wards w ON w.ward_id = sh.ward_id
GROUP BY s.staff_id
ORDER BY w.ward_name, ward_rank;

-- 6. Running total of admissions over time per ward (window function)
SELECT ward_id, admission_date,
       COUNT(*) OVER (PARTITION BY ward_id ORDER BY admission_date
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_admissions
FROM admissions
ORDER BY ward_id, admission_date;

-- 7. High-risk patients with 2+ incidents (aggregation + HAVING)
SELECT p.patient_id, p.risk_level, COUNT(i.incident_id) AS incident_count
FROM patients p
JOIN incidents i ON i.patient_id = p.patient_id
GROUP BY p.patient_id
HAVING incident_count >= 2
ORDER BY incident_count DESC;

-- 8. Current bed occupancy snapshot
SELECT w.ward_name, w.capacity,
       COUNT(a.admission_id) AS currently_admitted,
       ROUND(100.0 * COUNT(a.admission_id) / w.capacity, 1) AS occupancy_pct
FROM wards w
LEFT JOIN admissions a ON a.ward_id = w.ward_id AND a.discharge_date IS NULL
GROUP BY w.ward_id
ORDER BY occupancy_pct DESC;

-- 9. Night shifts that were understaffed AND had a high-severity incident within 3 days
--    (correlating two signals — the kind of insight that's hard to spot manually)
SELECT DISTINCT w.ward_name, sa.shift_date
FROM staffing_alerts sa
JOIN wards w ON w.ward_id = sa.ward_id
JOIN incidents i ON i.ward_id = sa.ward_id
  AND sa.shift_type = 'Night'
  AND i.severity = 'High'
  AND julianday(i.incident_date) BETWEEN julianday(sa.shift_date) - 3 AND julianday(sa.shift_date) + 3
ORDER BY sa.shift_date;

-- 10. Staff tenure vs the incident rate of the ward they work on
SELECT s.full_name, w.ward_name,
       CAST(julianday('2025-06-30') - julianday(s.hire_date) AS INTEGER) / 365 AS years_tenure,
       (SELECT COUNT(*) FROM incidents i WHERE i.ward_id = w.ward_id) AS ward_incident_count
FROM staff s
JOIN wards w ON w.ward_id = s.ward_id
ORDER BY ward_incident_count DESC, years_tenure DESC;