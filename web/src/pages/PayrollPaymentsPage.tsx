import { Fragment, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { Empty, PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import {
  PayrollApiError,
  payrollService,
  type PayrollPayment,
  type PayrollPaymentSummary,
  type PayrollPendingPayment,
} from '../modules/payroll/payrollService';

type RangePreset = 'TODAY' | 'WEEK' | 'FORTNIGHT' | 'MONTH' | 'CUSTOM';
type DateRange = { from: string; to: string };
type PaymentAttempt = { idempotencyKey: string; reason: string; sourceFingerprint: string };
const DEFAULT_PAYMENT_REASON = 'Pago completo confirmado desde el módulo de pagos';

const money = (value: number) => `RD$ ${Number(value || 0).toLocaleString('es-DO', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})}`;

const isoDate = (value: Date) => {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const rangeFor = (preset: Exclude<RangePreset, 'CUSTOM'>, reference = new Date()): DateRange => {
  const end = new Date(reference.getFullYear(), reference.getMonth(), reference.getDate());
  const start = new Date(end);

  if (preset === 'WEEK') {
    const daysSinceMonday = (end.getDay() + 6) % 7;
    start.setDate(end.getDate() - daysSinceMonday);
  } else if (preset === 'FORTNIGHT') {
    start.setDate(end.getDate() <= 15 ? 1 : 16);
  } else if (preset === 'MONTH') {
    start.setDate(1);
  }

  return { from: isoDate(start), to: isoDate(end) };
};

const displayDate = (value: string | null) => value
  ? new Date(`${value}T12:00:00`).toLocaleDateString('es-DO')
  : '—';

const displayDateTime = (value: string) => new Date(value).toLocaleString('es-DO');

const deductions = (payment: PayrollPendingPayment) => payment.afp
  + payment.sfs
  + payment.loan_discount
  + payment.credit_discount
  + payment.other_discounts;

const printPaymentSlip = (payment: PayrollPayment) => {
  const doc = new jsPDF();
  doc.text('CONTROLHORARIO · Volante de pago', 14, 16);
  doc.text(`${payment.employee_name} · ${payment.employee_code}`, 14, 25);
  autoTable(doc, {
    startY: 32,
    head: [['Concepto', 'Valor']],
    body: [
      ['Comprobante', payment.id],
      ['Fecha de pago', displayDateTime(payment.paid_at)],
      ['Período', `${displayDate(payment.journey_from)} al ${displayDate(payment.journey_to)}`],
      ['Jornadas incluidas', String(payment.journeys)],
      ['Bruto', money(payment.gross)],
      ['Horas extras', money(payment.overtime_pay)],
      ['AFP', money(payment.afp)],
      ['SFS', money(payment.sfs)],
      ['Préstamo', money(payment.loan_discount)],
      ['Crédito', money(payment.credit_discount)],
      ['Otros descuentos', money(payment.other_discounts)],
      ['Total pagado', money(payment.total_pending)],
      ['Motivo', payment.motive || 'Pago completo confirmado'],
      ['Fórmula', payment.formula || 'No disponible'],
    ],
  });
  doc.save(`volante-pago-${payment.id}.pdf`);
};

export function PayrollPaymentsPage() {
  const { hasPermission } = useAuth();
  const canPay = hasPermission('nomina.pagar');
  const initialRange = useMemo(() => rangeFor('FORTNIGHT'), []);
  const [preset, setPreset] = useState<RangePreset>('FORTNIGHT');
  const [range, setRange] = useState<DateRange>(initialRange);
  const [draftFrom, setDraftFrom] = useState(initialRange.from);
  const [draftTo, setDraftTo] = useState(initialRange.to);
  const [summary, setSummary] = useState<PayrollPaymentSummary | null>(null);
  const [pending, setPending] = useState<PayrollPendingPayment[]>([]);
  const [history, setHistory] = useState<PayrollPayment[]>([]);
  const [historyFilter, setHistoryFilter] = useState('');
  const [paymentReason, setPaymentReason] = useState(DEFAULT_PAYMENT_REASON);
  const [selectedPayment, setSelectedPayment] = useState<PayrollPendingPayment | null>(null);
  const [openDetail, setOpenDetail] = useState('');
  const [loading, setLoading] = useState(true);
  const [payingEmployee, setPayingEmployee] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const loadSequence = useRef(0);
  const attempts = useRef(new Map<string, PaymentAttempt>());

  const load = useCallback(async (selectedRange: DateRange) => {
    const sequence = ++loadSequence.current;
    setLoading(true);
    setError('');
    try {
      const [nextSummary, nextPending, nextHistory] = await Promise.all([
        payrollService.paymentSummary(selectedRange.from, selectedRange.to),
        payrollService.listPendingPayments(selectedRange.from, selectedRange.to),
        payrollService.listPaymentHistory(selectedRange.from, selectedRange.to),
      ]);
      if (sequence !== loadSequence.current) return;
      setSummary(nextSummary);
      setPending(nextPending);
      setHistory(nextHistory);
    } catch {
      if (sequence === loadSequence.current) {
        setError('No fue posible cargar los pagos para el rango seleccionado. Intenta nuevamente.');
      }
    } finally {
      if (sequence === loadSequence.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load(range);
  }, [load, range]);

  const pendingRows = useMemo(() => pending
    .filter((row) => row.total_pending > 0)
    .sort((a, b) => a.employee_code.localeCompare(b.employee_code)), [pending]);

  const filteredHistory = useMemo(() => {
    const query = historyFilter.trim().toLowerCase();
    return [...history]
      .filter((payment) => !query || `${payment.employee_code} ${payment.employee_name}`.toLowerCase().includes(query))
      .sort((a, b) => b.paid_at.localeCompare(a.paid_at));
  }, [history, historyFilter]);

  const choosePreset = (nextPreset: RangePreset) => {
    setPreset(nextPreset);
    if (nextPreset === 'CUSTOM') return;
    const nextRange = rangeFor(nextPreset);
    setDraftFrom(nextRange.from);
    setDraftTo(nextRange.to);
    setRange(nextRange);
    setSelectedPayment(null);
    setOpenDetail('');
    setNotice('');
  };

  const applyCustomRange = () => {
    setError('');
    setNotice('');
    if (!draftFrom || !draftTo) {
      setError('Selecciona las fechas desde y hasta.');
      return;
    }
    if (draftFrom > draftTo) {
      setError('La fecha desde no puede ser posterior a la fecha hasta.');
      return;
    }
    const nextRange = { from: draftFrom, to: draftTo };
    setPreset('CUSTOM');
    setSelectedPayment(null);
    setOpenDetail('');
    if (range.from === nextRange.from && range.to === nextRange.to) {
      void load(nextRange);
    } else {
      setRange(nextRange);
    }
  };

  const openPaymentConfirmation = (payment: PayrollPendingPayment) => {
    if (!canPay) return;
    const attemptId = `${range.from}:${range.to}:${payment.employee_id}`;
    const previousAttempt = attempts.current.get(attemptId);
    if (previousAttempt && previousAttempt.sourceFingerprint !== payment.source_fingerprint) {
      attempts.current.delete(attemptId);
    }
    setPaymentReason(
      previousAttempt?.sourceFingerprint === payment.source_fingerprint
        ? previousAttempt.reason
        : DEFAULT_PAYMENT_REASON,
    );
    setSelectedPayment(payment);
    setError('');
    setNotice('');
  };

  const confirmFullPayment = async (payment: PayrollPendingPayment) => {
    if (!canPay) {
      setError('No tienes el permiso nomina.pagar para confirmar pagos.');
      return;
    }
    const reason = paymentReason.trim();
    if (!reason) {
      setError('Escribe un motivo antes de confirmar el pago.');
      return;
    }

    const attemptId = `${range.from}:${range.to}:${payment.employee_id}`;
    const previousAttempt = attempts.current.get(attemptId);
    const attempt = previousAttempt?.sourceFingerprint === payment.source_fingerprint ? previousAttempt : {
      idempotencyKey: globalThis.crypto.randomUUID(),
      reason,
      sourceFingerprint: payment.source_fingerprint,
    };
    attempts.current.set(attemptId, attempt);
    setPayingEmployee(payment.employee_id);
    setError('');
    setNotice('');

    try {
      const registered = await payrollService.registerEmployeePayment(
        payment.employee_id,
        range.from,
        range.to,
        attempt.reason,
        attempt.idempotencyKey,
        attempt.sourceFingerprint,
      );
      attempts.current.delete(attemptId);
      setPending((current) => current.filter((row) => row.employee_id !== payment.employee_id));
      setHistory((current) => [registered, ...current.filter((row) => row.id !== registered.id)]);
      setSummary((current) => current ? {
        ...current,
        pendiente_a_pagar: Math.max(0, current.pendiente_a_pagar - registered.total_pending),
        ya_pagado: current.ya_pagado + registered.total_pending,
        empleados_pendientes: Math.max(0, current.empleados_pendientes - 1),
      } : current);
      setNotice(`Pago completo confirmado para ${registered.employee_name}.`);
      setSelectedPayment(null);
      await load(range);
    } catch (paymentError) {
      const errorParts = paymentError instanceof PayrollApiError
        ? [paymentError.code, paymentError.message, paymentError.details, paymentError.hint]
        : [paymentError instanceof Error ? paymentError.message : ''];
      const sourcesChanged = errorParts.some((part) => part?.includes('PAGO_CAMBIO_REQUIERE_CONFIRMACION'));
      if (sourcesChanged) {
        attempts.current.delete(attemptId);
        setSelectedPayment(null);
        setPaymentReason(DEFAULT_PAYMENT_REASON);
        await load(range);
        setError('Los movimientos pendientes cambiaron. Revisa los importes actualizados y confirma nuevamente.');
      } else {
        setError('No se pudo confirmar el pago. Reintenta: se conservará la misma clave idempotente.');
      }
    } finally {
      setPayingEmployee('');
    }
  };

  return <>
    <PageHeader
      eyebrow="NÓMINA"
      title="Pagos en tiempo real"
      description="Consulta saldos calculados, confirma el pago completo y conserva su volante e historial."
      action={<div className="button-row">
        <Link className="secondary" to="/nomina">Volver</Link>
        <button className="secondary" disabled={loading} onClick={() => void load(range)}>
          {loading ? 'Actualizando…' : 'Actualizar'}
        </button>
      </div>}
    />

    <section className="panel payroll-periods">
      <label>Rango rápido
        <select value={preset} onChange={(event) => choosePreset(event.target.value as RangePreset)}>
          <option value="TODAY">Hoy</option>
          <option value="WEEK">Esta semana</option>
          <option value="FORTNIGHT">Quincena actual</option>
          <option value="MONTH">Este mes</option>
          <option value="CUSTOM">Personalizado</option>
        </select>
      </label>
      <label>Desde
        <input type="date" value={draftFrom} onChange={(event) => { setDraftFrom(event.target.value); setPreset('CUSTOM'); }} />
      </label>
      <label>Hasta
        <input type="date" value={draftTo} onChange={(event) => { setDraftTo(event.target.value); setPreset('CUSTOM'); }} />
      </label>
      <button className="secondary" onClick={applyCustomRange}>Buscar</button>
    </section>

    {error && <div className="error" role="alert">{error}</div>}
    {notice && <section className="panel" role="status"><strong>{notice}</strong></section>}

    {selectedPayment && canPay && <section className="panel" role="dialog" aria-modal="true" aria-labelledby="payment-confirmation-title">
      <h2 id="payment-confirmation-title">Confirmar pago completo</h2>
      <p><strong>{selectedPayment.employee_name}</strong> · {selectedPayment.employee_code}</p>
      <p>
        <strong>Jornadas:</strong> {selectedPayment.journeys} · <strong>Rango:</strong>{' '}
        {displayDate(selectedPayment.journey_from)} – {displayDate(selectedPayment.journey_to)}
      </p>
      <section className="stats payroll-stats">
        <article className="stat"><span>Bruto</span><strong>{money(selectedPayment.gross)}</strong></article>
        <article className="stat"><span>Horas extras</span><strong>{money(selectedPayment.overtime_pay)}</strong></article>
        <article className="stat"><span>AFP+SFS</span><strong>{money(selectedPayment.afp + selectedPayment.sfs)}</strong></article>
        <article className="stat"><span>Desc. préstamo</span><strong>{money(selectedPayment.loan_discount)}</strong></article>
        <article className="stat"><span>Desc. crédito</span><strong>{money(selectedPayment.credit_discount)}</strong></article>
        <article className="stat"><span>Otros</span><strong>{money(selectedPayment.other_discounts)}</strong></article>
        <article className="stat"><span>Total pendiente</span><strong>{money(selectedPayment.total_pending)}</strong></article>
      </section>
      <label>Motivo
        <textarea
          value={paymentReason}
          maxLength={240}
          onChange={(event) => setPaymentReason(event.target.value)}
        />
      </label>
      <p>Esta operación registra el saldo completo y queda auditada. No se enviará un monto parcial.</p>
      <div className="button-row">
        <button className="secondary" disabled={Boolean(payingEmployee)} onClick={() => setSelectedPayment(null)}>Cancelar</button>
        <button
          className="primary"
          disabled={Boolean(payingEmployee) || !paymentReason.trim()}
          onClick={() => void confirmFullPayment(selectedPayment)}
        >{payingEmployee ? 'Confirmando…' : 'Confirmar pago completo'}</button>
      </div>
    </section>}

    {summary && <section className="stats payroll-stats">
      <article className="stat"><span>Pendiente a pagar</span><strong>{money(summary.pendiente_a_pagar)}</strong><small>Ganancias de jornadas del rango seleccionado que aún no fueron pagadas.</small></article>
      <article className="stat"><span>Ya pagado</span><strong>{money(summary.ya_pagado)}</strong><small>Pagos cuya fecha de pago cae dentro del rango seleccionado.</small></article>
      <article className="stat"><span>Empleados pendientes</span><strong>{summary.empleados_pendientes}</strong><small>Empleados con ganancias de jornadas pendientes en el rango seleccionado.</small></article>
    </section>}

    {loading && !summary ? <Empty text="Cargando pagos en tiempo real…" /> : <>
      <section className="panel">
        <h2>Pagos pendientes</h2>
        <p>La confirmación siempre registra el saldo completo calculado por el servidor. No se permiten montos parciales.</p>
      </section>
      {!pendingRows.length ? <Empty text="No hay pagos pendientes para el rango seleccionado." /> : <section className="table-wrap payroll-wide">
        <table>
          <thead><tr><th>Código</th><th>Nombre</th><th>Jornadas pendientes</th><th>Bruto</th><th>H/Extras</th><th>AFP+SFS</th><th>Desc. préstamo</th><th>Desc. crédito</th><th>Otros</th><th>Total pendiente</th><th>Detalle</th>{canPay && <th>PAGAR</th>}</tr></thead>
          <tbody>{pendingRows.map((payment) => {
            const expanded = openDetail === payment.employee_id;
            return <Fragment key={payment.employee_id}>
              <tr>
                <td>{payment.employee_code}</td>
                <td>{payment.employee_name}</td>
                <td>{payment.journeys}</td>
                <td>{money(payment.gross)}</td>
                <td>{money(payment.overtime_pay)}</td>
                <td>{money(payment.afp + payment.sfs)}</td>
                <td>{money(payment.loan_discount)}</td>
                <td>{money(payment.credit_discount)}</td>
                <td>{money(payment.other_discounts)}</td>
                <td><b>{money(payment.total_pending)}</b></td>
                <td><button className="secondary" onClick={() => setOpenDetail(expanded ? '' : payment.employee_id)}>{expanded ? 'Cerrar' : 'Ver detalle'}</button></td>
                {canPay && <td><button
                  className="primary"
                  disabled={Boolean(payingEmployee) || loading}
                  onClick={() => openPaymentConfirmation(payment)}
                >PAGAR</button></td>}
              </tr>
              {expanded && <tr className="payroll-slip">
                <td colSpan={canPay ? 12 : 11}>
                  <p><strong>Rango de jornadas:</strong> {displayDate(payment.journey_from)} – {displayDate(payment.journey_to)}</p>
                  <p><strong>Fórmula:</strong> {payment.formula || 'No disponible'}</p>
                  {payment.deduction_items.length ? <div>
                    <strong>Detalle de descuentos:</strong>
                    <ul>{payment.deduction_items.map((item, index) => {
                      const applied = Number(item.applied ?? item.amount ?? item.requested ?? 0);
                      const pendingAmount = item.pending == null ? null : Number(item.pending);
                      return <li key={`${String(item.type ?? 'descuento')}-${index}`}>
                        {String(item.type ?? `Descuento ${index + 1}`)}: {money(applied)}
                        {pendingAmount == null ? '' : ` · pendiente ${money(pendingAmount)}`}
                      </li>;
                    })}</ul>
                  </div> : <p>Sin desglose adicional de descuentos.</p>}
                </td>
              </tr>}
            </Fragment>;
          })}</tbody>
        </table>
      </section>}
    </>}

    <section className="panel payroll-periods">
      <div>
        <h2>Historial de pagos</h2>
        <p>Comprobantes inmutables del rango seleccionado.</p>
      </div>
      <label>Filtrar empleado
        <input
          type="search"
          value={historyFilter}
          placeholder="Código o nombre"
          onChange={(event) => setHistoryFilter(event.target.value)}
        />
      </label>
    </section>
    {!filteredHistory.length ? <Empty text="No hay pagos registrados para este rango y filtro." /> : <section className="table-wrap payroll-wide">
      <table>
        <thead><tr><th>Pagado</th><th>Código</th><th>Empleado</th><th>Período</th><th>Jornadas</th><th>Bruto</th><th>Descuentos</th><th>Total pagado</th><th>Motivo</th><th>Volante</th></tr></thead>
        <tbody>{filteredHistory.map((payment) => <tr key={payment.id}>
          <td>{displayDateTime(payment.paid_at)}</td>
          <td>{payment.employee_code}</td>
          <td>{payment.employee_name}</td>
          <td>{displayDate(payment.journey_from)} – {displayDate(payment.journey_to)}</td>
          <td>{payment.journeys}</td>
          <td>{money(payment.gross)}</td>
          <td>{money(deductions(payment))}</td>
          <td><b>{money(payment.total_pending)}</b></td>
          <td>{payment.motive || '—'}</td>
          <td><button className="secondary" onClick={() => printPaymentSlip(payment)}>Imprimir volante</button></td>
        </tr>)}</tbody>
      </table>
    </section>}
  </>;
}
