#!/usr/bin/env bash
# Runs the whole project: generate data, load it, reconcile, export, test.
set -e
mkdir -p data output

Rscript R/01_generate_data.R

rm -f recon.db
sqlite3 recon.db < sql/01_schema.sql
sqlite3 recon.db ".mode csv" \
  ".import --skip 1 data/legacy_ledger.csv legacy_ledger" \
  ".import --skip 1 data/erp_ledger.csv erp_ledger" \
  ".import --skip 1 data/account_map.csv account_map"
sqlite3 recon.db < sql/02_reconcile.sql
sqlite3 recon.db < sql/03_daily_cash.sql
sqlite3 recon.db < sql/04_pnl_allocation.sql

q() { sqlite3 -header -csv recon.db "$1" > "output/$2"; }
q "SELECT * FROM v_recon ORDER BY ref"                          recon_detail.csv
q "SELECT * FROM v_recon_summary ORDER BY lines DESC"           recon_summary.csv
q "SELECT * FROM v_exceptions ORDER BY status, ref"             exceptions.csv
q "SELECT * FROM v_daily_cash_diff ORDER BY entity, cash_date"  daily_cash_diff.csv
q "SELECT * FROM v_pnl_month ORDER BY entity, month, account_name" pnl_by_month.csv
q "SELECT * FROM v_allocated_pnl ORDER BY entity, month"        allocated_pnl.csv

Rscript R/02_checks.R
echo "Done. Results are in output/"
