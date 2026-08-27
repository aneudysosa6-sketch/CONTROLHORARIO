import fixture from "../../../../contracts/attendance-rc2-v1.json";
export type CanonicalJourneyState =
  "SIN_INICIAR" | "EN_CURSO" | "EN_PAUSA" | "FINALIZADA";
export type CanonicalJourneyAction =
  "INICIAR" | "PAUSAR" | "REANUDAR" | "FINALIZAR";
export const ATTENDANCE_CONTRACT_VERSION = fixture.contractVersion;
export function applyCanonicalTransition(
  from: CanonicalJourneyState,
  action: CanonicalJourneyAction,
) {
  const row = fixture.transitions.find(
    (x) => x.from === from && x.action === action,
  );
  if (!row) throw new Error("INVALID_CONTRACT");
  return {
    accepted: row.accepted,
    to: row.to as CanonicalJourneyState,
    error: "error" in row ? row.error : undefined,
  };
}
export function allowedCanonicalActions(
  from: CanonicalJourneyState,
): CanonicalJourneyAction[] {
  return fixture.transitions
    .filter((x) => x.from === from && x.accepted)
    .map((x) => x.action as CanonicalJourneyAction);
}
