# Walkthrough

One entry per object: what it does, why it is built that way, and what it returned on the committed data.

## v_legacy_mapped (sql/02_reconcile.sql)
- **Does:** joins each legacy line to the account map, so it carries the ERP account it should have landed on.
- **Why:** the two systems use different account codes. Nothing can be compared until both speak the same chart of accounts.
- **Returned:** 6,000 rows, one per legacy voucher.

## v_erp_agg
- **Does:** collapses the ERP ledger to one row per document with `COUNT(*)`, `MIN()` and `SUM()`.
- **Why:** a document posted twice would otherwise join twice and double the legacy line. `erp_rows = 2` is how a duplicate is detected, and `total_amount` shows its money effect.
- **Returned:** 5,990 rows from 6,002 ERP rows (12 duplicates collapsed).

## v_recon
- **Does:** a `LEFT JOIN` from legacy to ERP, then `UNION ALL` with ERP documents that have no legacy voucher. A `CASE` labels each line.
- **Why LEFT JOIN plus UNION:** it keeps unmatched lines from both sides and runs on any SQL engine, including ones with no full outer join.
- **Why the CASE order matters:** the first true condition wins. Missing is tested first because nothing else can be compared without a match; duplicate comes before amount because a duplicate's total would also look like an amount error.
- **Returned:** 6,015 lines: 5,873 matched and 142 exceptions.

## v_recon_summary and v_exceptions
- **Does:** counts and values each status; lists every line that is not matched.
- **Why:** the summary is what a manager reads; the exceptions list is what a reviewer clears.

## v_daily_cash and v_daily_cash_diff (sql/03_daily_cash.sql)
- **Does:** cash in minus cash out per entity per day in each system, side by side, then keeps the days that differ.
- **Why:** a total cash difference says something is wrong; a difference by date says where to look. A late posting shows as a shortfall on one day and the same amount extra a few days later.
- **How:** both systems are stacked with `UNION ALL`, each filling its own column and leaving the other at zero, then summed by entity and date.

## v_pnl_month, v_entity_month, v_month_totals, v_allocated_pnl (sql/04_pnl_allocation.sql)
- **Does:** monthly P&L per entity, then spreads the shared service centre's costs over the trading entities.
- **Formula:** allocated share = shared pool x entity revenue / group revenue.
- **Why revenue as the key:** it is simple, available monthly and hard to dispute. Headcount or floor area would be alternatives for HR or rent.
- **Returned:** six rows, two trading entities by three months.

## R/01_generate_data.R
- **Does:** creates the ledgers with `sample()` and `runif()`, then plants each break type on a separate set of vouchers.
- **Why an answer key:** without it there is no way to prove the reconciliation found everything.

## R/02_checks.R
- **Does:** `merge()` of the answer key with the exceptions, then `stopifnot()` on three conditions.
- **Why:** a reconciliation that is not tested is only an opinion.
