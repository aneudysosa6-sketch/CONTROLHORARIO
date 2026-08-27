package com.example.controlhorario.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class SpreadsheetExportPolicyTest {
    @Test fun neutralizesSpreadsheetFormulaPrefixes() {
        assertEquals("'=2+2", SpreadsheetExportPolicy.neutralize("=2+2"))
        assertEquals("'  @SUM(A1:A2)", SpreadsheetExportPolicy.neutralize("  @SUM(A1:A2)"))
        assertEquals("Empleado normal", SpreadsheetExportPolicy.neutralize("Empleado normal"))
    }

    @Test fun csvEscapesQuotesAfterNeutralizingFormula() {
        assertEquals("\"'=HYPERLINK(\"\"x\"\")\"", SpreadsheetExportPolicy.csvCell("=HYPERLINK(\"x\")"))
    }
}