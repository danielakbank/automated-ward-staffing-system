-- ============================================================
-- AUTOMATION LAYER
-- ============================================================

-- 1) AUTO-FLAG UNDERSTAFFED SHIFTS
-- Fires every time a shift is logged. Recounts staff on that
-- ward/date/shift, compares to the minimum requirement, and
-- writes an alert automatically if it falls short.

CREATE TRIGGER trg_flag_understaffed_shift
AFTER INSERT ON shifts
BEGIN
    INSERT INTO staffing_alerts (ward_id, shift_date, shift_type, staff_count, required_count, flagged_at)
    SELECT
        NEW.ward_id,
        NEW.shift_date,
        NEW.shift_type,
        (SELECT COUNT(*) FROM shifts
            WHERE ward_id = NEW.ward_id
              AND shift_date = NEW.shift_date
              AND shift_type = NEW.shift_type),
        sr.min_staff_required,
        datetime('now')
    FROM staffing_requirements sr
    WHERE sr.ward_id = NEW.ward_id
      AND sr.shift_type = NEW.shift_type
      AND (SELECT COUNT(*) FROM shifts
            WHERE ward_id = NEW.ward_id
              AND shift_date = NEW.shift_date
              AND shift_type = NEW.shift_type) < sr.min_staff_required
      AND NOT EXISTS (
          SELECT 1 FROM staffing_alerts sa
          WHERE sa.ward_id = NEW.ward_id
            AND sa.shift_date = NEW.shift_date
            AND sa.shift_type = NEW.shift_type
      );
END;

-- 2) AUTO-FLAG READMISSIONS WITHIN 30 DAYS
-- Fires every time a new admission is logged. Checks whether
-- that patient was discharged in the last 30 days, and if so,
-- marks the admission as a readmission and logs it.

CREATE TRIGGER trg_flag_readmission
AFTER INSERT ON admissions
BEGIN
    UPDATE admissions
    SET readmission_flag = 1
    WHERE admission_id = NEW.admission_id
      AND EXISTS (
          SELECT 1 FROM admissions prev
          WHERE prev.patient_id = NEW.patient_id
            AND prev.admission_id != NEW.admission_id
            AND prev.discharge_date IS NOT NULL
            AND julianday(NEW.admission_date) - julianday(prev.discharge_date) BETWEEN 0 AND 30
      );

    INSERT INTO readmission_alerts (patient_id, admission_id, days_since_last_discharge, flagged_at)
    SELECT
        NEW.patient_id,
        NEW.admission_id,
        CAST(julianday(NEW.admission_date) - julianday(prev.discharge_date) AS INTEGER),
        datetime('now')
    FROM admissions prev
    WHERE prev.patient_id = NEW.patient_id
      AND prev.admission_id != NEW.admission_id
      AND prev.discharge_date IS NOT NULL
      AND julianday(NEW.admission_date) - julianday(prev.discharge_date) BETWEEN 0 AND 30
    ORDER BY prev.discharge_date DESC
    LIMIT 1;
END;