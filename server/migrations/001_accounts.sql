-- PostgreSQL design draft, NOT executed by the SQLite development API.
-- Server-side authorization, consent verification and production controls required.
BEGIN;
CREATE TABLE accounts (
  id uuid PRIMARY KEY,
  display_name text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 40),
  created_at timestamptz NOT NULL DEFAULT now(),
  deletion_requested_at timestamptz
);
CREATE TABLE login_identities (
  provider text NOT NULL CHECK (provider IN ('email','yandex','vk')),
  subject text NOT NULL,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  verified_at timestamptz NOT NULL,
  PRIMARY KEY (provider,subject), UNIQUE(account_id,provider)
);
CREATE TABLE account_sessions (
  id uuid PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_hash bytea NOT NULL UNIQUE, csrf_hash bytea NOT NULL,
  device_label text NOT NULL, authenticated_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL, last_seen_at timestamptz NOT NULL,
  revoked_at timestamptz
);
CREATE INDEX account_sessions_owner ON account_sessions(account_id);
CREATE TABLE processing_basis (
  id uuid PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  purpose text NOT NULL, basis_type text NOT NULL,
  document_version text NOT NULL, document_digest bytea NOT NULL,
  evidence_reference text NOT NULL, verified_by text NOT NULL,
  verified_at timestamptz NOT NULL, revoked_at timestamptz,
  UNIQUE(id,account_id)
);
-- Only server-verified evidence, never a client boolean.
CREATE TABLE pharmacies (
  id uuid PRIMARY KEY,
  owner_account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  processing_basis_id uuid NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision>0), deleted_at timestamptz,
  FOREIGN KEY(processing_basis_id,owner_account_id)
    REFERENCES processing_basis(id,account_id) ON DELETE RESTRICT
);
CREATE TABLE pharmacy_memberships (
  pharmacy_id uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('editor','viewer')),
  accepted_at timestamptz NOT NULL,
  PRIMARY KEY(pharmacy_id,account_id)
);
-- Owner derives from pharmacies.owner_account_id; cannot be set via client role.
CREATE TABLE pharmacy_invitations (
  id uuid PRIMARY KEY,
  pharmacy_id uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  token_hash bytea NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('editor','viewer')),
  recipient_identity_digest bytea, expires_at timestamptz NOT NULL,
  accepted_by uuid REFERENCES accounts(id) ON DELETE SET NULL,
  accepted_at timestamptz, revoked_at timestamptz
);
CREATE TABLE medicine_packages (
  id uuid PRIMARY KEY,
  pharmacy_id uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload)='object'),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision>0), deleted_at timestamptz
);
CREATE INDEX medicine_packages_pharmacy ON medicine_packages(pharmacy_id);
-- Payload fields require API validation of names, quantities, dates and locations.
CREATE TABLE private_reminders (
  id uuid PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  medicine_id uuid REFERENCES medicine_packages(id) ON DELETE SET NULL,
  processing_basis_id uuid NOT NULL,
  schedule jsonb NOT NULL CHECK (jsonb_typeof(schedule)='object'),
  time_zone text NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision>0), deleted_at timestamptz,
  UNIQUE(id,account_id),
  FOREIGN KEY(processing_basis_id,account_id)
    REFERENCES processing_basis(id,account_id) ON DELETE RESTRICT
);
CREATE TABLE private_intake_events (
  id uuid PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reminder_id uuid NOT NULL, occurred_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('taken','skipped')),
  FOREIGN KEY(reminder_id,account_id)
    REFERENCES private_reminders(id,account_id) ON DELETE CASCADE
);
-- Pharmacy membership never implies access to private reminders/intake.
CREATE TABLE sync_operations (
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  operation_id uuid NOT NULL, request_digest bytea NOT NULL,
  result_reference uuid, completed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(account_id,operation_id)
);
-- Repeating a key with different content must return a conflict.
CREATE TABLE security_audit (
  id uuid PRIMARY KEY,
  account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
  event_type text NOT NULL, occurred_at timestamptz NOT NULL DEFAULT now()
);
-- No medical payloads, OTP, tokens or unrestricted metadata.
-- Retention and backup deletion must be defined before processing real data.
COMMIT;
