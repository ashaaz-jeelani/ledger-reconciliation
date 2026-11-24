# 01_generate_data.R
# Builds two versions of the same ledger for a fictional three-entity group:
#   legacy_ledger.csv  the old accounting system (source of truth)
#   erp_ledger.csv     the new ERP after migration, with breaks seeded on purpose
# Every seeded break is written to seeded_breaks.csv so the SQL can be tested against it.
# Base R only.

set.seed(2026)
n <- 6000

# ---- chart of accounts: legacy code -> ERP general ledger code ----
account_map <- data.frame(
  legacy_account = c("L100", "L110", "L200", "L210", "L220", "L230", "L240", "L300", "L310", "L320"),
  gl_account     = c("4000", "4100", "5000", "5100", "5200", "5300", "5400", "6000", "6100", "6200"),
  account_name   = c("Sales - products", "Sales - services", "Purchases", "Salaries and wages",
                     "Power and fuel", "Repairs and maintenance", "Marketing",
                     "Group IT", "Group HR and admin", "Head office rent"),
  account_type   = c("Revenue", "Revenue", rep("Direct expense", 5), rep("Shared cost", 3)),
  stringsAsFactors = FALSE
)

# ---- legacy ledger ----
dates  <- seq(as.Date("2026-04-01"), as.Date("2026-06-30"), by = "day")
entity <- sample(c("E01", "E02", "E03"), n, replace = TRUE, prob = c(0.50, 0.35, 0.15))

legacy_account <- character(n)
amount <- numeric(n)
for (i in 1:n) {
  if (entity[i] == "E03") {                      # E03 is the shared service centre
    legacy_account[i] <- sample(c("L300", "L310", "L320"), 1)
    amount[i] <- runif(1, 5000, 40000)
  } else if (runif(1) < 0.45) {                  # trading entities: revenue line
    legacy_account[i] <- sample(c("L100", "L110"), 1)
    amount[i] <- runif(1, 5000, 150000)
  } else {                                       # trading entities: direct expense line
    legacy_account[i] <- sample(c("L200", "L210", "L220", "L230", "L240"), 1)
    amount[i] <- runif(1, 2000, 90000)
  }
}

legacy <- data.frame(
  voucher_no     = sprintf("V%06d", 1:n),
  txn_date       = sample(dates, n, replace = TRUE),
  entity         = entity,
  legacy_account = legacy_account,
  amount         = round(amount, 2),
  pay_mode       = sample(c("Cash", "Bank"), n, replace = TRUE, prob = c(0.3, 0.7)),
  stringsAsFactors = FALSE
)

# ---- ERP ledger: start as a clean migration of the legacy ledger ----
m <- merge(legacy, account_map[, c("legacy_account", "gl_account")], by = "legacy_account")
erp <- data.frame(
  doc_ref      = m$voucher_no,
  posting_date = m$txn_date,
  entity_code  = m$entity,
  gl_account   = m$gl_account,
  amount       = m$amount,
  pay_mode     = m$pay_mode,
  stringsAsFactors = FALSE
)

# ---- seed the breaks on separate sets of vouchers ----
k <- c(missing_erp = 25, amount = 30, timing = 40, duplicate = 12, mismap = 20)
picked <- sample(legacy$voucher_no, sum(k))
ends   <- cumsum(k)
starts <- ends - k + 1
set_missing <- picked[starts[1]:ends[1]]
set_amount  <- picked[starts[2]:ends[2]]
set_timing  <- picked[starts[3]:ends[3]]
set_dup     <- picked[starts[4]:ends[4]]
set_mismap  <- picked[starts[5]:ends[5]]

# 1. vouchers that never reached the ERP
erp <- erp[!(erp$doc_ref %in% set_missing), ]

# 2. amount keyed wrongly in the ERP
r <- erp$doc_ref %in% set_amount
erp$amount[r] <- round(erp$amount[r] + sample(c(-1, 1), sum(r), replace = TRUE) * runif(sum(r), 10, 5000), 2)

# 3. posted one to three days late in the ERP
r <- erp$doc_ref %in% set_timing
erp$posting_date[r] <- erp$posting_date[r] + sample(1:3, sum(r), replace = TRUE)

# 4. posted twice in the ERP
erp <- rbind(erp, erp[erp$doc_ref %in% set_dup, ])

# 5. posted to the wrong general ledger account
r <- which(erp$doc_ref %in% set_mismap)
for (i in r) {
  erp$gl_account[i] <- sample(setdiff(account_map$gl_account, erp$gl_account[i]), 1)
}

# 6. entries that exist only in the ERP
extra <- data.frame(
  doc_ref      = sprintf("V9%05d", 1:15),
  posting_date = sample(dates, 15, replace = TRUE),
  entity_code  = sample(c("E01", "E02"), 15, replace = TRUE),
  gl_account   = sample(account_map$gl_account[1:7], 15, replace = TRUE),
  amount       = round(runif(15, 2000, 60000), 2),
  pay_mode     = sample(c("Cash", "Bank"), 15, replace = TRUE),
  stringsAsFactors = FALSE
)
erp <- rbind(erp, extra)
erp <- erp[sample(nrow(erp)), ]                  # shuffle so order gives nothing away

# ---- answer key ----
seeded <- data.frame(
  ref = c(set_missing, set_amount, set_timing, set_dup, set_mismap, extra$doc_ref),
  expected_status = c(rep("Missing in ERP", 25), rep("Amount mismatch", 30), rep("Timing difference", 40),
                      rep("Duplicate in ERP", 12), rep("Account mismapped", 20), rep("Missing in legacy", 15)),
  stringsAsFactors = FALSE
)

legacy$txn_date  <- format(legacy$txn_date, "%Y-%m-%d")
erp$posting_date <- format(erp$posting_date, "%Y-%m-%d")

write.csv(legacy,      "data/legacy_ledger.csv", row.names = FALSE, quote = FALSE)
write.csv(erp,         "data/erp_ledger.csv",    row.names = FALSE, quote = FALSE)
write.csv(account_map, "data/account_map.csv",   row.names = FALSE, quote = FALSE)
write.csv(seeded,      "data/seeded_breaks.csv", row.names = FALSE, quote = FALSE)

cat("legacy rows:", nrow(legacy), " ERP rows:", nrow(erp), " seeded breaks:", nrow(seeded), "\n")
