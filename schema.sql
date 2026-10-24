-- SmartRide NEMT -- PostgreSQL schema (schema only, no data).
--
-- GENERATED from the Alembic migrations (head = 0008). DO NOT HAND EDIT.
-- To regenerate after adding a migration, from backend/ with a scratch database:
--   createdb smartride_schema_dump
--   DATABASE_URL=postgresql+asyncpg://USER:PASS@HOST/smartride_schema_dump alembic upgrade head
--   pg_dump -U USER -s --no-owner --no-privileges smartride_schema_dump > schema.sql
--   (then re-add this header and the alembic_version stamp at the bottom)
--
-- Load: psql -U postgres -d smartride -f schema.sql
-- The hospital seed rows are inserted by migration 0001, not by this file; to get
-- them, run `alembic upgrade head` on an empty database instead of loading this.

--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: driver_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.driver_status AS ENUM (
    'available',
    'busy',
    'offline'
);


--
-- Name: ride_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ride_status AS ENUM (
    'pending',
    'driver_assigned',
    'driver_en_route',
    'patient_picked_up',
    'arrived_at_hospital',
    'completed',
    'cancelled'
);


--
-- Name: ride_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ride_type AS ENUM (
    'emergency',
    'scheduled'
);


--
-- Name: severity_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.severity_level AS ENUM (
    '1',
    '2',
    '3',
    '4',
    '5'
);


--
-- Name: specialty; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.specialty AS ENUM (
    'cardiology',
    'neurology',
    'orthopedics',
    'obstetrics',
    'pediatrics',
    'psychiatry',
    'oncology',
    'nephrology',
    'pulmonology',
    'gastroenterology',
    'ophthalmology',
    'ent',
    'dermatology',
    'general_emergency'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'patient',
    'driver',
    'admin'
);


--
-- Name: sync_driver_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_driver_location() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
          IF NEW.current_lat IS NOT NULL AND NEW.current_lng IS NOT NULL THEN
            NEW.location := ST_SetSRID(ST_MakePoint(NEW.current_lng, NEW.current_lat), 4326)::geography;
          END IF;
          RETURN NEW;
        END;
        $$;


--
-- Name: sync_hospital_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_hospital_location() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
          NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
          RETURN NEW;
        END;
        $$;


--
-- Name: wallet_transactions_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_transactions_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
          RAISE EXCEPTION 'wallet_transactions is append-only (% not allowed)', TG_OP;
        END;
        $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: analytics_hourly; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_hourly (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    snapshot_hour timestamp with time zone NOT NULL,
    city character varying(100) NOT NULL,
    zone_id character varying(50),
    total_rides integer DEFAULT 0,
    emergency_rides integer DEFAULT 0,
    avg_eta_seconds numeric(8,2),
    missed_appointments integer DEFAULT 0,
    driver_utilisation_pct numeric(5,2),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: drivers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drivers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    full_name character varying(100) NOT NULL,
    license_no character varying(50) NOT NULL,
    vehicle_plate character varying(20) NOT NULL,
    vehicle_type character varying(50) NOT NULL,
    is_verified boolean DEFAULT false,
    status public.driver_status DEFAULT 'offline'::public.driver_status,
    current_lat double precision,
    current_lng double precision,
    location public.geography(Point,4326),
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    wallet_balance_pkr numeric(12,2) DEFAULT '0'::double precision NOT NULL
);


--
-- Name: hospitals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hospitals (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(200) NOT NULL,
    address text NOT NULL,
    city character varying(100) NOT NULL,
    lat double precision NOT NULL,
    lng double precision NOT NULL,
    location public.geography(Point,4326),
    phone character varying(20),
    specialties json DEFAULT '[]'::json NOT NULL,
    ed_capacity integer DEFAULT 50 NOT NULL,
    ed_current_load integer DEFAULT 0 NOT NULL,
    fhir_endpoint text,
    coordinator_phone character varying(20),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patients (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    full_name character varying(100) NOT NULL,
    date_of_birth date,
    mobility_needs text,
    emergency_contact_name character varying(100),
    emergency_contact_phone character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: rides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rides (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    patient_id uuid NOT NULL,
    driver_id uuid,
    hospital_id uuid,
    ride_type public.ride_type NOT NULL,
    status public.ride_status DEFAULT 'pending'::public.ride_status NOT NULL,
    pickup_lat double precision NOT NULL,
    pickup_lng double precision NOT NULL,
    pickup_address text,
    scheduled_for timestamp with time zone,
    requested_at timestamp with time zone DEFAULT now(),
    driver_assigned_at timestamp with time zone,
    pickup_at timestamp with time zone,
    arrived_at timestamp with time zone,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancel_reason text,
    estimated_fare_pkr numeric(10,2),
    final_fare_pkr numeric(10,2),
    created_at timestamp with time zone DEFAULT now(),
    patient_rating numeric(2,1),
    rating_comment text,
    queued_at timestamp with time zone DEFAULT now() NOT NULL,
    symptom_text text,
    CONSTRAINT ck_rides_patient_rating_range CHECK (((patient_rating >= (1)::numeric) AND (patient_rating <= (5)::numeric)))
);


--
-- Name: triage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.triage_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ride_id uuid NOT NULL,
    symptom_text text NOT NULL,
    predicted_specialty public.specialty NOT NULL,
    confidence_score numeric(5,4) NOT NULL,
    severity_level public.severity_level NOT NULL,
    rule_override boolean DEFAULT false,
    model_version character varying(50) NOT NULL,
    inference_ms integer,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    role public.user_role NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    phone character varying(20) NOT NULL,
    password_hash text NOT NULL,
    role public.user_role NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    fcm_token text
);


--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_transactions (
    id uuid NOT NULL,
    driver_id uuid NOT NULL,
    ride_id uuid,
    kind character varying(20) NOT NULL,
    amount numeric(12,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    idempotency_key text,
    admin_user_id uuid,
    payment_method text,
    CONSTRAINT ck_wallet_amount_sign CHECK (((((kind)::text = 'topup'::text) AND (amount > (0)::numeric)) OR (((kind)::text = 'commission'::text) AND (amount < (0)::numeric)) OR ((kind)::text = 'adjustment'::text))),
    CONSTRAINT ck_wallet_kind CHECK (((kind)::text = ANY ((ARRAY['topup'::character varying, 'commission'::character varying, 'adjustment'::character varying])::text[])))
);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: analytics_hourly analytics_hourly_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_hourly
    ADD CONSTRAINT analytics_hourly_pkey PRIMARY KEY (id);


--
-- Name: analytics_hourly analytics_hourly_snapshot_hour_city_zone_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_hourly
    ADD CONSTRAINT analytics_hourly_snapshot_hour_city_zone_id_key UNIQUE (snapshot_hour, city, zone_id);


--
-- Name: drivers drivers_license_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_license_no_key UNIQUE (license_no);


--
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (id);


--
-- Name: drivers drivers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_key UNIQUE (user_id);


--
-- Name: drivers drivers_vehicle_plate_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_vehicle_plate_key UNIQUE (vehicle_plate);


--
-- Name: hospitals hospitals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitals
    ADD CONSTRAINT hospitals_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: patients patients_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_user_id_key UNIQUE (user_id);


--
-- Name: rides rides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rides
    ADD CONSTRAINT rides_pkey PRIMARY KEY (id);


--
-- Name: triage_events triage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triage_events
    ADD CONSTRAINT triage_events_pkey PRIMARY KEY (id);


--
-- Name: triage_events uq_triage_events_ride_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triage_events
    ADD CONSTRAINT uq_triage_events_ride_id UNIQUE (ride_id);


--
-- Name: wallet_transactions uq_wallet_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT uq_wallet_idempotency_key UNIQUE (idempotency_key);


--
-- Name: wallet_transactions uq_wallet_ride_kind; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT uq_wallet_ride_kind UNIQUE (ride_id, kind);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_analytics_hour; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analytics_hour ON public.analytics_hourly USING btree (snapshot_hour DESC);


--
-- Name: idx_drivers_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drivers_location ON public.drivers USING gist (location);


--
-- Name: idx_drivers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drivers_status ON public.drivers USING btree (status);


--
-- Name: idx_hospitals_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hospitals_city ON public.hospitals USING btree (city);


--
-- Name: idx_hospitals_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hospitals_location ON public.hospitals USING gist (location);


--
-- Name: idx_rides_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rides_driver ON public.rides USING btree (driver_id);


--
-- Name: idx_rides_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rides_patient ON public.rides USING btree (patient_id);


--
-- Name: idx_rides_requested_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rides_requested_at ON public.rides USING btree (requested_at DESC);


--
-- Name: idx_rides_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rides_status ON public.rides USING btree (status);


--
-- Name: idx_triage_ride; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_triage_ride ON public.triage_events USING btree (ride_id);


--
-- Name: ix_drivers_available_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_drivers_available_location ON public.drivers USING btree (current_lat, current_lng) WHERE ((status = 'available'::public.driver_status) AND is_verified);


--
-- Name: ix_rides_driver_status_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_rides_driver_status_completed ON public.rides USING btree (driver_id, status, completed_at DESC);


--
-- Name: ix_rides_hospital_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_rides_hospital_id ON public.rides USING btree (hospital_id);


--
-- Name: ix_rides_pending_requested_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_rides_pending_requested_at ON public.rides USING btree (requested_at) WHERE (status = 'pending'::public.ride_status);


--
-- Name: ix_user_roles_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_roles_user_id ON public.user_roles USING btree (user_id);


--
-- Name: ix_wallet_transactions_driver_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_wallet_transactions_driver_created ON public.wallet_transactions USING btree (driver_id, created_at);


--
-- Name: uq_rides_active_emergency_per_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_rides_active_emergency_per_patient ON public.rides USING btree (patient_id) WHERE ((ride_type = 'emergency'::public.ride_type) AND (status = ANY (ARRAY['pending'::public.ride_status, 'driver_assigned'::public.ride_status, 'driver_en_route'::public.ride_status, 'patient_picked_up'::public.ride_status, 'arrived_at_hospital'::public.ride_status])));


--
-- Name: uq_user_roles_user_role; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_user_roles_user_role ON public.user_roles USING btree (user_id, role);


--
-- Name: drivers trg_driver_location; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_driver_location BEFORE INSERT OR UPDATE ON public.drivers FOR EACH ROW EXECUTE FUNCTION public.sync_driver_location();


--
-- Name: hospitals trg_hospital_location; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_hospital_location BEFORE INSERT OR UPDATE ON public.hospitals FOR EACH ROW EXECUTE FUNCTION public.sync_hospital_location();


--
-- Name: wallet_transactions trg_wallet_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_wallet_append_only BEFORE DELETE OR UPDATE ON public.wallet_transactions FOR EACH ROW EXECUTE FUNCTION public.wallet_transactions_append_only();


--
-- Name: drivers drivers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: patients patients_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: rides rides_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rides
    ADD CONSTRAINT rides_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id) ON DELETE RESTRICT;


--
-- Name: rides rides_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rides
    ADD CONSTRAINT rides_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.hospitals(id);


--
-- Name: rides rides_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rides
    ADD CONSTRAINT rides_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id) ON DELETE RESTRICT;


--
-- Name: triage_events triage_events_ride_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triage_events
    ADD CONSTRAINT triage_events_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: wallet_transactions wallet_transactions_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: wallet_transactions wallet_transactions_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id) ON DELETE RESTRICT;


--
-- Name: wallet_transactions wallet_transactions_ride_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id);


--
-- PostgreSQL database dump complete
--


-- Mark the database as being at the migration head this file was generated from.
INSERT INTO public.alembic_version (version_num) VALUES ('0008');
