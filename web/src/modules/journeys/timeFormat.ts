export function formatDurationMinutes(totalMinutes: number | null | undefined): string {
  const numericValue = Number(totalMinutes);

  if (!Number.isFinite(numericValue) || numericValue <= 0) {
    return '0 h 00 min';
  }

  const normalized = Math.max(0, Math.floor(numericValue));
  const hours = Math.floor(normalized / 60);
  const minutes = normalized % 60;
  const minuteLabel = String(minutes).padStart(2, '0');

  return `${hours} h ${minuteLabel} min`;
}
