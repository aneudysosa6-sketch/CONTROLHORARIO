const FORMULA_PREFIX = /^[\s]*[=+\-@]/;

export function safeSpreadsheetText(value: unknown): string {
  const text = String(value ?? '');
  return FORMULA_PREFIX.test(text) ? "'" + text : text;
}