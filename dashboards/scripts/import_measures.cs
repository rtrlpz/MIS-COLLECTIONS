// ============================================================
// import_measures.cs — Bulk DAX measure importer for Tabular Editor 2
// Reads measures.tsv and creates all measures + calculated tables
// ============================================================

// === CONFIGURATION ===
// Resolve TSV path relative to this script: <repo>/dashboards/dax/measures.tsv
var scriptDir = System.IO.Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
var tsvPath = System.IO.Path.GetFullPath(System.IO.Path.Combine(scriptDir, "..", "dax", "measures.tsv"));

// Helper class to map format strings
public static class MeasureHelper
{
    public static string GetFormatString(string name, string table, string expression)
    {
        if (expression.TrimStart().StartsWith("DATATABLE")) return null;
        if (name.Contains("Status") || name.Contains("Color") || name.Contains("Tier") || name.Contains("Alert") || name.Contains("Income Segment")) return null;
        if (name.Contains("Rate") || name.Contains(" %") || name.EndsWith("%") || name.Contains("Gap") || name.Contains("Mora Rate") || name.Contains("Arrears to Balance") || name.Contains("THT Alignment") || name.Contains("Agent Cure Rate") || name.Contains("Self-Cure Rate") || name.Contains("Online Payment") || name.Contains("Branch/ATM Payment") || name.Contains("OFI Payment") || name.Contains("Collection Efficiency") || name.Contains("Credit Utilization") || name.Contains("Cure Rate by Vintage") || name.Contains("Deterioration Rate") || name.Contains("Skip Path") && name.Contains("Rate")) return "0.0%";
        if (name.Contains("$") || name.Contains("Amount") || name.Contains("Balance") && !name.Contains("Rate") || name.Contains("Recovery") && !name.Contains("Rate") && !name.Contains("per") || name.Contains("Cost") || name.Contains("Arrears") && !name.Contains("Rate") && !name.Contains("Balance") || name.Contains("Promised")) return "$#,##0";
        if (name.Contains("per Hr") || name.Contains("per Op") || name.Contains("per THT") || name.Contains("per Hour") || name.Contains("Hours") || name.Contains("Contacts per") || name.Contains("RPC per") || name.Contains("Cures per") || name.Contains("Avg Credit Limit") || name.Contains("Average Vintage") || name.Contains("Recovery per") || name.Contains("Cost per Account") || name.Contains("Cost per Dollar")) return "#,##0.00";
        return "#,##0";
    }
}

// === IMPORT ===
var content = System.IO.File.ReadAllText(tsvPath);
var lines = content.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
int created = 0, skipped = 0, tablesCreated = 0;

foreach (var line in lines.Skip(1)) // skip header
{
    var cols = line.Split('\t');
    if (cols.Length < 3) { skipped++; continue; }

    var tsvTableName = cols[0].Trim();
    var measureName = cols[1].Trim();
    var expression = cols[2].Trim();

    // Strip outer quotes from expression
    if (expression.StartsWith("\"") && expression.EndsWith("\""))
        expression = expression.Substring(1, expression.Length - 2);

    // Unescape doubled quotes
    expression = expression.Replace("\"\"", "\"");

    // 1. SMART TABLE MATCHING: Look for exact match OR match with a prefix like "public "
    var table = Model.Tables.FirstOrDefault(t =>
        t.Name.Equals(tsvTableName, StringComparison.OrdinalIgnoreCase) ||
        t.Name.EndsWith(" " + tsvTableName, StringComparison.OrdinalIgnoreCase));

    // 2. Handle actual calculated tables from the TSV (DATATABLE expressions)
    if (expression.TrimStart().StartsWith("DATATABLE"))
    {
        if (table != null) table.Delete();
        Model.AddCalculatedTable(tsvTableName, expression);
        tablesCreated++;
        created++;
        continue;
    }

    // 3. Handle standard measures
    // Create a dummy calculated table to house the measure only if it truly doesn't exist
    if (table == null)
    {
        table = Model.AddCalculatedTable(tsvTableName, "{BLANK()}");
        tablesCreated++;
    }

    // Regular measure — delete if exists (re-runnable)
    var existingMeasure = table.Measures.FirstOrDefault(m => m.Name == measureName);
    if (existingMeasure != null) existingMeasure.Delete();

    // Add the measure
    var measure = table.AddMeasure(measureName, expression);
    measure.SetAnnotation("IMPORT_SOURCE", "csv_to_tsv");

    // Set format string via helper class
    var fmt = MeasureHelper.GetFormatString(measureName, tsvTableName, expression);
    if (fmt != null)
        measure.FormatString = fmt;

    // Set display folder (everything after the underscore prefix)
    var folder = tsvTableName.TrimStart('_');
    measure.DisplayFolder = folder;
    created++;
}

// === SUMMARY ===
Output("=== Import Complete ===");
Output("Tables created: " + tablesCreated);
Output("Measures/CalcTables created: " + created);
Output("Rows skipped: " + skipped);
Output("Total tables in model: " + Model.Tables.Count);
Output("Total measures in model: " + Model.AllMeasures.Count());