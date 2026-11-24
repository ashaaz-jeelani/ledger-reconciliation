-- 03_daily_cash.sql : cash movement per entity per day in each system, and the days that disagree
-- Cash in = revenue received in cash. Cash out = any expense paid in cash.

DROP VIEW IF EXISTS v_daily_cash_diff;
DROP VIEW IF EXISTS v_daily_cash;

CREATE VIEW v_daily_cash AS
SELECT c.entity, c.cash_date,
       ROUND(SUM(c.legacy_cash), 2)                   AS legacy_cash,
       ROUND(SUM(c.erp_cash), 2)                      AS erp_cash,
       ROUND(SUM(c.erp_cash) - SUM(c.legacy_cash), 2) AS diff
FROM (
  SELECT entity, txn_date AS cash_date,
         CASE WHEN account_type = 'Revenue' THEN amount ELSE -amount END AS legacy_cash,
         0 AS erp_cash
  FROM v_legacy_mapped
  WHERE pay_mode = 'Cash'
  UNION ALL
  SELECT e.entity_code, e.posting_date,
         0,
         CASE WHEN m.account_type = 'Revenue' THEN e.amount ELSE -e.amount END
  FROM erp_ledger e
  JOIN (SELECT DISTINCT gl_account, account_type FROM account_map) m ON m.gl_account = e.gl_account
  WHERE e.pay_mode = 'Cash'
) AS c
GROUP BY c.entity, c.cash_date;

CREATE VIEW v_daily_cash_diff AS
SELECT * FROM v_daily_cash WHERE ABS(diff) > 0.005;
