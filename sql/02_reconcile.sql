-- 02_reconcile.sql : match every legacy voucher to the ERP and label the result

DROP VIEW IF EXISTS v_exceptions;
DROP VIEW IF EXISTS v_recon_summary;
DROP VIEW IF EXISTS v_recon;
DROP VIEW IF EXISTS v_erp_agg;
DROP VIEW IF EXISTS v_legacy_mapped;

-- Legacy lines translated onto the ERP chart of accounts
CREATE VIEW v_legacy_mapped AS
SELECT l.voucher_no, l.txn_date, l.entity, l.legacy_account, l.amount, l.pay_mode,
       m.gl_account AS mapped_gl, m.account_name, m.account_type
FROM legacy_ledger l
JOIN account_map m ON m.legacy_account = l.legacy_account;

-- One row per ERP document, so a document posted twice shows as erp_rows = 2
CREATE VIEW v_erp_agg AS
SELECT doc_ref,
       COUNT(*)          AS erp_rows,
       MIN(posting_date) AS posting_date,
       MIN(entity_code)  AS entity_code,
       MIN(gl_account)   AS gl_account,
       MIN(amount)       AS amount,
       SUM(amount)       AS total_amount
FROM erp_ledger
GROUP BY doc_ref;

-- Part 1: every legacy voucher, with its ERP match if there is one
-- Part 2: ERP documents that have no legacy voucher at all
CREATE VIEW v_recon AS
SELECT l.voucher_no   AS ref,
       l.entity       AS entity,
       l.txn_date     AS legacy_date,
       e.posting_date AS erp_date,
       l.account_name AS account_name,
       l.mapped_gl    AS expected_gl,
       e.gl_account   AS erp_gl,
       l.amount       AS legacy_amount,
       e.total_amount AS erp_amount,
       ROUND(COALESCE(e.total_amount, 0) - l.amount, 2) AS amount_diff,
       CASE
         WHEN e.doc_ref IS NULL               THEN 'Missing in ERP'
         WHEN e.erp_rows > 1                  THEN 'Duplicate in ERP'
         WHEN ABS(e.amount - l.amount) > 0.005 THEN 'Amount mismatch'
         WHEN e.gl_account <> l.mapped_gl     THEN 'Account mismapped'
         WHEN e.posting_date <> l.txn_date    THEN 'Timing difference'
         ELSE 'Matched'
       END AS status
FROM v_legacy_mapped l
LEFT JOIN v_erp_agg e ON e.doc_ref = l.voucher_no

UNION ALL

SELECT e.doc_ref, e.entity_code, NULL, e.posting_date, m.account_name, NULL, e.gl_account,
       NULL, e.total_amount, ROUND(e.total_amount, 2), 'Missing in legacy'
FROM v_erp_agg e
LEFT JOIN legacy_ledger l ON l.voucher_no = e.doc_ref
LEFT JOIN (SELECT DISTINCT gl_account, account_name FROM account_map) m ON m.gl_account = e.gl_account
WHERE l.voucher_no IS NULL;

-- Count and value of each kind of result
CREATE VIEW v_recon_summary AS
SELECT status, COUNT(*) AS lines, ROUND(SUM(ABS(amount_diff)), 2) AS value_of_difference
FROM v_recon
GROUP BY status;

-- Everything a reviewer has to look at
CREATE VIEW v_exceptions AS
SELECT * FROM v_recon WHERE status <> 'Matched';
