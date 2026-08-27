import { safeSpreadsheetText } from '../src/modules/reports/spreadsheetText.ts';

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

assert(safeSpreadsheetText('=2+2') === "'=2+2", 'equals formula must be neutralized');
assert(safeSpreadsheetText('  @SUM(A1:A2)') === "'  @SUM(A1:A2)", 'whitespace formula must be neutralized');
assert(safeSpreadsheetText('+CMD') === "'+CMD", 'plus formula must be neutralized');
assert(safeSpreadsheetText('Empleado normal') === 'Empleado normal', 'normal text must be preserved');
console.log('spreadsheetExportSecurity: PASS');