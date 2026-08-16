// ============================================================
// create_calc_group.cs — Creates _Time Intelligence Calculation Group
// Run AFTER import_measures.cs in Tabular Editor 2
// ============================================================

// 1. Delete existing TI measures (redundant with CG)
var tiTable = Model.Tables["_Time Intelligence"];
if (tiTable != null)
{
    foreach (var m in tiTable.Measures.ToList())
        m.Delete();
    tiTable.Delete();
}

// 2. Create Calculation Group via Model API (no constructors)
var cgTable = Model.AddCalculationGroup("_Time Intelligence");
cgTable.Description = "Time Intelligence — apply as slicer to any base measure";

// 3. Create all 18 calculation items

var ci00 = cgTable.AddCalculationItem("Current Period");
ci00.Expression = "SELECTEDMEASURE()";
ci00.Ordinal = 0;

var ci01 = cgTable.AddCalculationItem("Prior Month");
ci01.Expression = "CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH))";
ci01.Ordinal = 1;

var ci02 = cgTable.AddCalculationItem("MoM Change");
ci02.Expression = "SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH))";
ci02.FormatString = "+0.0%;-0.0%";
ci02.Ordinal = 2;

var ci03 = cgTable.AddCalculationItem("MoM % Change");
ci03.Expression = "VAR _Prior = CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH)) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)";
ci03.FormatString = "+0.0%;-0.0%";
ci03.Ordinal = 3;

var ci04 = cgTable.AddCalculationItem("Prior Week");
ci04.Expression = "VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) RETURN CALCULATE(SELECTEDMEASURE(), _Dates)";
ci04.Ordinal = 4;

var ci05 = cgTable.AddCalculationItem("WoW Change");
ci05.Expression = "VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) VAR _Prior = CALCULATE(SELECTEDMEASURE(), _Dates) RETURN SELECTEDMEASURE() - _Prior";
ci05.FormatString = "+0.0%;-0.0%";
ci05.Ordinal = 5;

var ci06 = cgTable.AddCalculationItem("WoW % Change");
ci06.Expression = "VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) VAR _Prior = CALCULATE(SELECTEDMEASURE(), _Dates) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)";
ci06.FormatString = "+0.0%;-0.0%";
ci06.Ordinal = 6;

var ci07 = cgTable.AddCalculationItem("Prior Day");
ci07.Expression = "CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY))";
ci07.Ordinal = 7;

var ci08 = cgTable.AddCalculationItem("DoD Change");
ci08.Expression = "SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY))";
ci08.FormatString = "+0.0%;-0.0%";
ci08.Ordinal = 8;

var ci09 = cgTable.AddCalculationItem("DoD % Change");
ci09.Expression = "VAR _Prior = CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY)) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)";
ci09.FormatString = "+0.0%;-0.0%";
ci09.Ordinal = 9;

var ci10 = cgTable.AddCalculationItem("Prior Year");
ci10.Expression = "CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date]))";
ci10.Ordinal = 10;

var ci11 = cgTable.AddCalculationItem("YoY Change");
ci11.Expression = "SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date]))";
ci11.FormatString = "+0.0%;-0.0%";
ci11.Ordinal = 11;

var ci12 = cgTable.AddCalculationItem("YoY % Change");
ci12.Expression = "VAR _Prior = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date])) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)";
ci12.FormatString = "+0.0%;-0.0%";
ci12.Ordinal = 12;

var ci13 = cgTable.AddCalculationItem("Overall Avg");
ci13.Expression = "CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar'))";
ci13.Ordinal = 13;

var ci14 = cgTable.AddCalculationItem("OTC Change");
ci14.Expression = "SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar'))";
ci14.FormatString = "+0.0%;-0.0%";
ci14.Ordinal = 14;

var ci15 = cgTable.AddCalculationItem("OTC % Change");
ci15.Expression = "VAR _Overall = CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar')) RETURN DIVIDE(SELECTEDMEASURE() - _Overall, _Overall)";
ci15.FormatString = "+0.0%;-0.0%";
ci15.Ordinal = 15;

var ci16 = cgTable.AddCalculationItem("YTD");
ci16.Expression = "CALCULATE(SELECTEDMEASURE(), DATESYTD('Dim_Calendar'[date]))";
ci16.Ordinal = 16;

var ci17 = cgTable.AddCalculationItem("Rolling 3M");
ci17.Expression = "CALCULATE(SELECTEDMEASURE(), DATESINPERIOD('Dim_Calendar'[date], LASTDATE('Dim_Calendar'[date]), -3, MONTH))";
ci17.Ordinal = 17;

// 4. Summary
Output("=== Calculation Group Created ===");
Output("Table: _Time Intelligence (Calculation Group)");
Output("Items: " + cgTable.CalculationItems.Count);
Output("");
Output("NOTE: The 118 individual TI measures from the CSV are still imported.");
Output("They can be DELETED after verifying the CG works correctly.");
Output("The CG must be renamed to match 'Dim_Calendar' date table.");
