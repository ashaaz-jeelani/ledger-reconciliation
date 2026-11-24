# 02_checks.R
# Tests the SQL output against the answer key. Stops with an error if anything is off.
# Base R only.

recon  <- read.csv("output/recon_detail.csv",  stringsAsFactors = FALSE)
exc    <- read.csv("output/exceptions.csv",    stringsAsFactors = FALSE)
seeded <- read.csv("data/seeded_breaks.csv",   stringsAsFactors = FALSE)
legacy <- read.csv("data/legacy_ledger.csv",   stringsAsFactors = FALSE)
alloc  <- read.csv("output/allocated_pnl.csv", stringsAsFactors = FALSE)
pnl    <- read.csv("output/pnl_by_month.csv",  stringsAsFactors = FALSE)

# 1. every seeded break is found, with the right label, and nothing else is flagged
chk <- merge(seeded, exc[, c("ref", "status")], by = "ref", all = TRUE)
stopifnot(!any(is.na(chk$status)))            # no seeded break was missed
stopifnot(!any(is.na(chk$expected_status)))   # no false alarm
stopifnot(all(chk$status == chk$expected_status))
cat("PASS 1: all", nrow(seeded), "seeded breaks found and labelled correctly, no false alarms\n")

# 2. control total: every legacy voucher appears exactly once in the reconciliation
stopifnot(sum(recon$status != "Missing in legacy") == nrow(legacy))
stopifnot(!any(duplicated(recon$ref)))
cat("PASS 2: all", nrow(legacy), "legacy vouchers accounted for exactly once\n")

# 3. the shared cost allocated out equals the shared cost pool, month by month
pool <- aggregate(amount ~ month, data = pnl[pnl$account_type == "Shared cost", ], FUN = sum)
out  <- aggregate(allocated_shared ~ month, data = alloc, FUN = sum)
cmp  <- merge(pool, out, by = "month")
stopifnot(all(abs(cmp$amount - cmp$allocated_shared) < 0.05))
cat("PASS 3: shared costs fully allocated in each of", nrow(cmp), "months\n")
