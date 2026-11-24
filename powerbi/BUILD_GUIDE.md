# Power BI build guide

Builds a three-page dashboard from the files in `output/`. Written for Power BI Desktop. Menu names can differ slightly between versions.

## 1. Load the data

1. Open Power BI Desktop and choose **Blank report**.
2. **Home** > **Get data** > **Text/CSV**.
3. Select `output/recon_detail.csv` and click **Open**, then **Transform Data**.
4. In Power Query, check the column types (click the icon left of each column name):
   - `legacy_date`, `erp_date`: **Date**
   - `legacy_amount`, `erp_amount`, `amount_diff`: **Decimal number**
   - `expected_gl`, `erp_gl`: **Text**
5. **Home** > **Close & Apply**.
6. Repeat steps 2 to 5 for `daily_cash_diff.csv` (`cash_date` as Date) and `allocated_pnl.csv` (`month` as Text).

## 2. Create the measures

In the **Data** pane on the right, right-click `recon_detail` > **New measure**. Paste one measure at a time and press Enter.

```
Total Lines = COUNTROWS(recon_detail)
Matched Lines = CALCULATE(COUNTROWS(recon_detail), recon_detail[status] = "Matched")
Exceptions = [Total Lines] - [Matched Lines]
Match Rate = DIVIDE([Matched Lines], [Total Lines])
Value of Differences = SUMX(recon_detail, ABS(recon_detail[amount_diff]))
```

Right-click `daily_cash_diff` > **New measure**:

```
Net Cash Difference = SUM(daily_cash_diff[diff])
```

Right-click `allocated_pnl` > **New measure**:

```
Profit Margin = DIVIDE(SUM(allocated_pnl[profit]), SUM(allocated_pnl[revenue]))
```

Click `Match Rate`, then **Measure tools** > **Format** > **Percentage**. Do the same for `Profit Margin`.

## 3. Page 1: Reconciliation

1. Double-click the page tab at the bottom and rename it `Reconciliation`.
2. Add four **Card** visuals, one each for `Total Lines`, `Match Rate`, `Exceptions` and `Value of Differences`.
3. Add a **Clustered bar chart**: Y-axis `status`, X-axis `Exceptions`.
4. Add a **Stacked column chart**: X-axis `entity`, Y-axis `Exceptions`, Legend `status`.
5. Add a **Table**: `ref`, `entity`, `status`, `legacy_amount`, `erp_amount`, `amount_diff`. In the **Filters** pane, drag `status` onto the table's filter and untick **Matched**.
6. Add a **Slicer** on `entity`.

Check: the cards should show 6,015 lines, 97.6% and 142 exceptions, and `Value of Differences` should equal the total of the last column in `output/recon_summary.csv`.

## 4. Page 2: Cash by date

1. Click **+** at the bottom to add a page and rename it `Cash by date`.
2. Add a **Clustered column chart**: X-axis `cash_date`, Y-axis `diff`.
3. Add a **Card** for `Net Cash Difference`.
4. Add a **Table**: `entity`, `cash_date`, `legacy_cash`, `erp_cash`, `diff`.
5. Add a **Slicer** on `entity`.

What to look for: late postings appear as a negative bar followed a few days later by a positive bar of the same size.

## 5. Page 3: P&L and allocation

1. Add a page and rename it `P&L and allocation`.
2. Add a **Matrix**: Rows `entity`, Columns `month`, Values `revenue`, `direct_expense`, `allocated_shared`, `profit`.
3. Add a **Card** for `Profit Margin`.
4. Add a **Clustered column chart**: X-axis `month`, Y-axis `profit`, Legend `entity`.

## 6. Save and publish to the repository

1. **File** > **Save as** > `powerbi/ledger_reconciliation.pbix`.
2. **File** > **Export** > **Export to PDF**, save as `powerbi/dashboard.pdf`.
3. Take a screenshot of page 1, save it as `powerbi/dashboard.png`, and add this line under "Results" in `README.md`:

```
![Dashboard](powerbi/dashboard.png)
```
