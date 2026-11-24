-- 01_schema.sql : empty tables that the three CSV files are loaded into
DROP TABLE IF EXISTS legacy_ledger;
DROP TABLE IF EXISTS erp_ledger;
DROP TABLE IF EXISTS account_map;

CREATE TABLE legacy_ledger (
  voucher_no     TEXT,
  txn_date       TEXT,   -- YYYY-MM-DD
  entity         TEXT,
  legacy_account TEXT,
  amount         REAL,
  pay_mode       TEXT    -- Cash or Bank
);

CREATE TABLE erp_ledger (
  doc_ref      TEXT,
  posting_date TEXT,     -- YYYY-MM-DD
  entity_code  TEXT,
  gl_account   TEXT,
  amount       REAL,
  pay_mode     TEXT
);

CREATE TABLE account_map (
  legacy_account TEXT,
  gl_account     TEXT,
  account_name   TEXT,
  account_type   TEXT    -- Revenue, Direct expense or Shared cost
);
