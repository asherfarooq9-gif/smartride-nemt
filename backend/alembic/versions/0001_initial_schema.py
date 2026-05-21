"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-05-21

"""
from typing import Sequence, Union
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS postgis')
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')

    op.execute("CREATE TYPE user_role    AS ENUM ('patient','driver','admin')")
    op.execute("CREATE TYPE ride_type    AS ENUM ('emergency','scheduled')")
    op.execute(
        "CREATE TYPE ride_status AS ENUM ("
        "'pending','driver_assigned','driver_en_route',"
        "'patient_picked_up','arrived_at_hospital','completed','cancelled')"
    )
    op.execute("CREATE TYPE driver_status AS ENUM ('available','busy','offline')")
    op.execute("CREATE TYPE severity_level AS ENUM ('1','2','3','4','5')")
    op.execute(
        "CREATE TYPE specialty AS ENUM ("
        "'cardiology','neurology','orthopedics','obstetrics',"
        "'pediatrics','psychiatry','oncology','nephrology',"
        "'pulmonology','gastroenterology','ophthalmology',"
        "'ent','dermatology','general_emergency')"
    )

    op.execute("""
        CREATE TABLE users (
            id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            phone         VARCHAR(20) UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role          user_role NOT NULL,
            is_active     BOOLEAN DEFAULT TRUE,
            created_at    TIMESTAMPTZ DEFAULT NOW(),
            updated_at    TIMESTAMPTZ DEFAULT NOW()
        )
    """)

    op.execute("""
        CREATE TABLE patients (
            id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id                 UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            full_name               VARCHAR(100) NOT NULL,
            date_of_birth           DATE,
            mobility_needs          TEXT,
            emergency_contact_name  VARCHAR(100),
            emergency_contact_phone VARCHAR(20),
            created_at              TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX idx_patients_user ON patients(user_id)")

    op.execute("""
        CREATE TABLE drivers (
            id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id       UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            full_name     VARCHAR(100) NOT NULL,
            license_no    VARCHAR(50) UNIQUE NOT NULL,
            vehicle_plate VARCHAR(20) UNIQUE NOT NULL,
            vehicle_type  VARCHAR(50) NOT NULL,
            is_verified   BOOLEAN DEFAULT FALSE,
            status        driver_status DEFAULT 'offline',
            current_lat   DOUBLE PRECISION,
            current_lng   DOUBLE PRECISION,
            location      GEOGRAPHY(POINT, 4326),
            last_seen_at  TIMESTAMPTZ,
            created_at    TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX idx_drivers_user     ON drivers(user_id)")
    op.execute("CREATE INDEX idx_drivers_status   ON drivers(status)")
    op.execute("CREATE INDEX idx_drivers_location ON drivers USING GIST(location)")

    op.execute("""
        CREATE TABLE hospitals (
            id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            name              VARCHAR(200) NOT NULL,
            address           TEXT NOT NULL,
            city              VARCHAR(100) NOT NULL,
            lat               DOUBLE PRECISION NOT NULL,
            lng               DOUBLE PRECISION NOT NULL,
            location          GEOGRAPHY(POINT, 4326),
            phone             VARCHAR(20),
            specialties       JSON NOT NULL DEFAULT '[]',
            ed_capacity       INTEGER NOT NULL DEFAULT 50,
            ed_current_load   INTEGER NOT NULL DEFAULT 0,
            fhir_endpoint     TEXT,
            coordinator_phone VARCHAR(20),
            is_active         BOOLEAN DEFAULT TRUE,
            created_at        TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX idx_hospitals_location ON hospitals USING GIST(location)")
    op.execute("CREATE INDEX idx_hospitals_city     ON hospitals(city)")

    op.execute("""
        CREATE TABLE rides (
            id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            patient_id         UUID NOT NULL REFERENCES patients(id),
            driver_id          UUID REFERENCES drivers(id),
            hospital_id        UUID REFERENCES hospitals(id),
            ride_type          ride_type NOT NULL,
            status             ride_status NOT NULL DEFAULT 'pending',
            pickup_lat         DOUBLE PRECISION NOT NULL,
            pickup_lng         DOUBLE PRECISION NOT NULL,
            pickup_address     TEXT,
            scheduled_for      TIMESTAMPTZ,
            requested_at       TIMESTAMPTZ DEFAULT NOW(),
            driver_assigned_at TIMESTAMPTZ,
            pickup_at          TIMESTAMPTZ,
            arrived_at         TIMESTAMPTZ,
            completed_at       TIMESTAMPTZ,
            cancelled_at       TIMESTAMPTZ,
            cancel_reason      TEXT,
            estimated_fare_pkr NUMERIC(10,2),
            final_fare_pkr     NUMERIC(10,2),
            created_at         TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX idx_rides_patient      ON rides(patient_id)")
    op.execute("CREATE INDEX idx_rides_driver       ON rides(driver_id)")
    op.execute("CREATE INDEX idx_rides_status       ON rides(status)")
    op.execute("CREATE INDEX idx_rides_requested_at ON rides(requested_at DESC)")

    op.execute("""
        CREATE TABLE triage_events (
            id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            ride_id             UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            symptom_text        TEXT NOT NULL,
            predicted_specialty specialty NOT NULL,
            confidence_score    NUMERIC(5,4) NOT NULL,
            severity_level      severity_level NOT NULL,
            rule_override       BOOLEAN DEFAULT FALSE,
            model_version       VARCHAR(50) NOT NULL,
            inference_ms        INTEGER,
            created_at          TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX idx_triage_ride ON triage_events(ride_id)")

    op.execute("""
        CREATE TABLE hospital_alerts (
            id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            ride_id     UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            hospital_id UUID NOT NULL REFERENCES hospitals(id),
            channel     VARCHAR(20) NOT NULL,
            payload     JSONB,
            sent_at     TIMESTAMPTZ,
            status      VARCHAR(20) DEFAULT 'pending',
            error_msg   TEXT
        )
    """)

    op.execute("""
        CREATE TABLE family_notifications (
            id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            ride_id         UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
            recipient_phone VARCHAR(20) NOT NULL,
            message_body    TEXT NOT NULL,
            twilio_sid      VARCHAR(100),
            sent_at         TIMESTAMPTZ DEFAULT NOW(),
            status          VARCHAR(20) DEFAULT 'pending'
        )
    """)

    op.execute("""
        CREATE TABLE analytics_hourly (
            id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            snapshot_hour          TIMESTAMPTZ NOT NULL,
            city                   VARCHAR(100) NOT NULL,
            zone_id                VARCHAR(50),
            total_rides            INTEGER DEFAULT 0,
            emergency_rides        INTEGER DEFAULT 0,
            avg_eta_seconds        NUMERIC(8,2),
            missed_appointments    INTEGER DEFAULT 0,
            driver_utilisation_pct NUMERIC(5,2),
            created_at             TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(snapshot_hour, city, zone_id)
        )
    """)
    op.execute("CREATE INDEX idx_analytics_hour ON analytics_hourly(snapshot_hour DESC)")

    op.execute("""
        CREATE OR REPLACE FUNCTION sync_driver_location()
        RETURNS TRIGGER AS $$
        BEGIN
          IF NEW.current_lat IS NOT NULL AND NEW.current_lng IS NOT NULL THEN
            NEW.location := ST_SetSRID(ST_MakePoint(NEW.current_lng, NEW.current_lat), 4326)::geography;
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_driver_location
        BEFORE INSERT OR UPDATE ON drivers
        FOR EACH ROW EXECUTE FUNCTION sync_driver_location()
    """)
    op.execute("""
        CREATE OR REPLACE FUNCTION sync_hospital_location()
        RETURNS TRIGGER AS $$
        BEGIN
          NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_hospital_location
        BEFORE INSERT OR UPDATE ON hospitals
        FOR EACH ROW EXECUTE FUNCTION sync_hospital_location()
    """)

    op.execute("""
        INSERT INTO hospitals (name, address, city, lat, lng, phone, specialties, ed_capacity, coordinator_phone) VALUES
        ('Pakistan Institute of Medical Sciences (PIMS)', 'G-8/3, Islamabad', 'Islamabad', 33.7005, 73.0679, '+92519255000',
          '["cardiology","neurology","orthopedics","obstetrics","pediatrics","oncology","nephrology","pulmonology","gastroenterology","general_emergency"]'::json, 120, '+92519255001'),
        ('Shifa International Hospital', 'Sector H-8/4, Islamabad', 'Islamabad', 33.6715, 73.0566, '+92518463000',
          '["cardiology","neurology","orthopedics","obstetrics","pediatrics","oncology","nephrology","ophthalmology","ent","dermatology","general_emergency"]'::json, 100, '+92518463001'),
        ('Poly Clinic Hospital', 'G-6/2, Islamabad', 'Islamabad', 33.7215, 73.0826, '+92519207500',
          '["cardiology","orthopedics","pediatrics","obstetrics","general_emergency"]'::json, 60, '+92519207501'),
        ('Holy Family Hospital', 'Murree Road, Rawalpindi', 'Rawalpindi', 33.5811, 73.0479, '+92519290301',
          '["cardiology","neurology","orthopedics","obstetrics","pediatrics","psychiatry","general_emergency"]'::json, 80, '+92519290302'),
        ('Benazir Bhutto Hospital', 'Murree Road, Rawalpindi', 'Rawalpindi', 33.5751, 73.0462, '+92519290401',
          '["cardiology","orthopedics","obstetrics","pediatrics","general_emergency"]'::json, 70, '+92519290402')
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS analytics_hourly CASCADE")
    op.execute("DROP TABLE IF EXISTS family_notifications CASCADE")
    op.execute("DROP TABLE IF EXISTS hospital_alerts CASCADE")
    op.execute("DROP TABLE IF EXISTS triage_events CASCADE")
    op.execute("DROP TABLE IF EXISTS rides CASCADE")
    op.execute("DROP TABLE IF EXISTS hospitals CASCADE")
    op.execute("DROP TABLE IF EXISTS drivers CASCADE")
    op.execute("DROP TABLE IF EXISTS patients CASCADE")
    op.execute("DROP TABLE IF EXISTS users CASCADE")
    op.execute("DROP TYPE IF EXISTS specialty CASCADE")
    op.execute("DROP TYPE IF EXISTS severity_level CASCADE")
    op.execute("DROP TYPE IF EXISTS driver_status CASCADE")
    op.execute("DROP TYPE IF EXISTS ride_status CASCADE")
    op.execute("DROP TYPE IF EXISTS ride_type CASCADE")
    op.execute("DROP TYPE IF EXISTS user_role CASCADE")
