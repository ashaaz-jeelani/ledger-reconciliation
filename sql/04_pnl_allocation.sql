-- 04_pnl_allocation.sql : monthly P&L per entity, with shared costs allocated by share of revenue
-- E03 is the shared service centre. Its costs are spread over E01 and E02.

DROP VIEW IF EXISTS v_allocated_pnl;
DROP VIEW IF EXISTS v_month_totals;
DROP VIEW IF EXISTS v_entity_month;
DROP VIEW IF EXISTS v_pnl_month;

-- P&L lines by entity, month and account
CREATE VIEW v_pnl_month AS
SELECT entity, substr(txn_date, 1, 7) AS month, account_type, account_name,
       ROUND(SUM(amount), 2) AS amount
FROM v_legacy_mapped
GROUP BY entity, substr(txn_date, 1, 7), account_type, account_name;

-- Revenue and direct expense of each trading entity per month
CREATE VIEW v_entity_month AS
SELECT entity, month,
       SUM(CASE WHEN account_type = 'Revenue'        THEN amount ELSE 0 END) AS revenue,
       SUM(CASE WHEN account_type = 'Direct expense' THEN amount ELSE 0 END) AS direct_expense
FROM v_pnl_month
WHERE account_type <> 'Shared cost'
GROUP BY entity, month;

-- Group revenue and the shared cost pool per month
CREATE VIEW v_month_totals AS
SELECT month,
       SUM(CASE WHEN account_type = 'Revenue'     THEN amount ELSE 0 END) AS group_revenue,
       SUM(CASE WHEN account_type = 'Shared cost' THEN amount ELSE 0 END) AS shared_pool
FROM v_pnl_month
GROUP BY month;

-- allocated share = shared pool x entity revenue / group revenue
CREATE VIEW v_allocated_pnl AS
SELECT e.entity, e.month,
       ROUND(e.revenue, 2)        AS revenue,
       ROUND(e.direct_expense, 2) AS direct_expense,
       ROUND(t.shared_pool * e.revenue / t.group_revenue, 2) AS allocated_shared,
       ROUND(e.revenue - e.direct_expense - t.shared_pool * e.revenue / t.group_revenue, 2) AS profit
FROM v_entity_month e
JOIN v_month_totals t ON t.month = e.month;
