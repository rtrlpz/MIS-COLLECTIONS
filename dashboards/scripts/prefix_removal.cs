// ============================================================
// Remove "public " prefix from all tables
// ============================================================

int renameCount = 0;

foreach (var table in Model.Tables)
{
    // Check if the table name starts with "public "
    if (table.Name.StartsWith("public ", StringComparison.OrdinalIgnoreCase))
    {
        // Remove the first 7 characters ("public ")
        table.Name = table.Name.Substring(7);
        renameCount++;
    }
}

Output("Tables renamed: " + renameCount);