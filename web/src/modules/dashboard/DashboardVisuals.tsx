import { memo, useEffect, useId, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { Check, Filter, RotateCcw, type LucideIcon } from 'lucide-react';
import type { ReportFiltersValue } from '../reports/ReportFilters';

export type ChartPoint = { label: string; value: number };
export type DashboardFilterOption = { label: string; value: string };

const clamp = (value: number, minimum = 0, maximum = 100) => Math.min(maximum, Math.max(minimum, value));

export const AnimatedNumber = memo(function AnimatedNumber({
  value,
  format = (current) => new Intl.NumberFormat('es-DO', { maximumFractionDigits: 2 }).format(current),
}: {
  value: number;
  format?: (value: number) => string;
}) {
  const previous = useRef(0);
  const [displayed, setDisplayed] = useState(0);

  useEffect(() => {
    const start = previous.current;
    const difference = value - start;
    previous.current = value;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setDisplayed(value);
      return;
    }
    const startedAt = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const progress = clamp((now - startedAt) / 620, 0, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setDisplayed(start + difference * eased);
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [value]);

  return <><span aria-hidden="true">{format(displayed)}</span><span className="sr-only">{format(value)}</span></>;
});

export const Sparkline = memo(function Sparkline({ points, label }: { points: ChartPoint[]; label: string }) {
  if (points.length < 2) return <div className="exec-sparkline-empty" aria-label={`${label}: sin histórico suficiente`}><span /></div>;
  const width = 150;
  const height = 42;
  const maximum = Math.max(...points.map((point) => point.value), 1);
  const minimum = Math.min(...points.map((point) => point.value), 0);
  const range = Math.max(maximum - minimum, 1);
  const coordinates = points.map((point, index) => {
    const x = (index / Math.max(points.length - 1, 1)) * width;
    const y = height - 5 - ((point.value - minimum) / range) * (height - 10);
    return `${x},${y}`;
  }).join(' ');
  return <svg className="exec-sparkline" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={`${label}: ${points.map((point) => `${point.label} ${point.value}`).join(', ')}`}>
    <polyline points={coordinates} fill="none" vectorEffect="non-scaling-stroke" />
  </svg>;
});

function Variation({ current, previous, increaseIsPositive }: { current: number; previous?: number; increaseIsPositive: boolean }) {
  if (previous == null) return <span className="exec-comparison neutral">Sin histórico comparable</span>;
  const difference = current - previous;
  const percentage = previous === 0 ? null : Math.abs((difference / previous) * 100);
  const direction = difference === 0 ? 'neutral' : (difference > 0) === increaseIsPositive ? 'up' : 'down';
  const prefix = difference > 0 ? '+' : '';
  return <span className={`exec-comparison ${direction}`}>
    {prefix}{difference} {percentage == null ? 'vs. anterior' : `· ${percentage.toFixed(0)}% vs. anterior`}
  </span>;
}

export const KpiCard = memo(function KpiCard({
  label,
  value,
  previous,
  icon: Icon,
  points,
  tone = 'blue',
  helper,
  increaseIsPositive = true,
}: {
  label: string;
  value: number;
  previous?: number;
  icon: LucideIcon;
  points: ChartPoint[];
  tone?: 'blue' | 'violet' | 'cyan' | 'amber';
  helper?: string;
  increaseIsPositive?: boolean;
}) {
  return <article className={`exec-kpi-card tone-${tone}`}>
    <div className="exec-kpi-heading"><span className="exec-kpi-icon" aria-hidden="true"><Icon /></span><span>{label}</span></div>
    <strong><AnimatedNumber value={value} format={(current) => Math.round(current).toLocaleString('es-DO')} /></strong>
    <Variation current={value} previous={previous} increaseIsPositive={increaseIsPositive} />
    <Sparkline points={points} label={label} />
    {helper && <small>{helper}</small>}
  </article>;
});

type FinancialState = 'loading' | 'error' | 'blocked' | 'success';

export const FinancialCard = memo(function FinancialCard({
  label,
  value,
  icon: Icon,
  state,
  points,
  format,
  message,
  tone = 'blue',
}: {
  label: string;
  value: number | null;
  icon: LucideIcon;
  state: FinancialState;
  points: ChartPoint[];
  format: (value: number) => string;
  message?: string;
  tone?: 'blue' | 'violet' | 'cyan';
}) {
  const stateLabel = state === 'success' ? 'Actualizado' : state === 'loading' ? 'Calculando' : state === 'blocked' ? 'Bloqueado' : 'Error';
  return <article className={`exec-financial-card tone-${tone}`} aria-busy={state === 'loading'}>
    <header><div><span className="exec-financial-icon" aria-hidden="true"><Icon /></span><span>{label}</span></div><span className={`exec-state-pill state-${state}`}>{stateLabel}</span></header>
    {state === 'loading' ? <div className="exec-value-skeleton" /> : value != null ? <strong><AnimatedNumber value={value} format={format} /></strong> : <strong className="exec-state-value">{state === 'blocked' ? 'Cálculo bloqueado' : 'No disponible'}</strong>}
    <Sparkline points={points} label={label} />
    <small title={message}>{message || (points.length > 1 ? 'Datos reales del período seleccionado' : 'Sin histórico suficiente para comparar')}</small>
  </article>;
});

export const DonutGauge = memo(function DonutGauge({ label, value, total, icon: Icon }: { label: string; value: number; total: number; icon: LucideIcon }) {
  const hasData = total > 0;
  const percentage = hasData ? clamp((value / total) * 100) : 0;
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (percentage / 100) * circumference;
  return <article className={`exec-gauge-card${hasData ? '' : ' no-data'}`}>
    <div className="exec-donut" role="img" aria-label={hasData ? `${label}: ${value} de ${total}, ${Math.round(percentage)} por ciento` : `${label}: sin datos`}>
      <svg viewBox="0 0 108 108" aria-hidden="true">
        <circle className="track" cx="54" cy="54" r={radius} />
        <circle className="value" cx="54" cy="54" r={radius} strokeDasharray={circumference} strokeDashoffset={offset} />
      </svg>
      <div><Icon /><strong>{hasData ? `${Math.round(percentage)}%` : '—'}</strong></div>
    </div>
    <div><b>{label}</b><span>{hasData ? `${value} de ${total}` : 'Sin datos'}</span></div>
  </article>;
});

export const LineChart = memo(function LineChart({ title, subtitle, points, formatValue }: { title: string; subtitle: string; points: ChartPoint[]; formatValue: (value: number) => string }) {
  const id = useId().replace(/:/g, '');
  if (points.length < 2) return <ChartShell title={title} subtitle={subtitle}><ChartEmpty /></ChartShell>;
  const width = 680;
  const height = 250;
  const paddingX = 34;
  const paddingTop = 24;
  const paddingBottom = 42;
  const maximum = Math.max(...points.map((point) => point.value), 1);
  const chartHeight = height - paddingTop - paddingBottom;
  const chartWidth = width - paddingX * 2;
  const positions = points.map((point, index) => ({
    ...point,
    x: paddingX + (index / Math.max(points.length - 1, 1)) * chartWidth,
    y: paddingTop + chartHeight - (point.value / maximum) * chartHeight,
  }));
  const path = positions.map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x} ${point.y}`).join(' ');
  const area = `${path} L ${positions.at(-1)?.x ?? width - paddingX} ${height - paddingBottom} L ${positions[0]?.x ?? paddingX} ${height - paddingBottom} Z`;
  return <ChartShell title={title} subtitle={subtitle}>
    <svg className="exec-line-chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={`${title}: ${points.map((point) => `${point.label} ${formatValue(point.value)}`).join(', ')}`}>
      <defs><linearGradient id={`area-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#6f63ff" stopOpacity=".34" /><stop offset="1" stopColor="#6f63ff" stopOpacity="0" /></linearGradient></defs>
      {[0, .25, .5, .75, 1].map((step) => <line key={step} className="grid" x1={paddingX} x2={width - paddingX} y1={paddingTop + chartHeight * step} y2={paddingTop + chartHeight * step} />)}
      <path className="area" d={area} fill={`url(#area-${id})`} />
      <path className="line" d={path} />
      {positions.map((point, index) => <g key={`${point.label}-${index}`}><circle cx={point.x} cy={point.y} r="4" /><text x={point.x} y={height - 16} textAnchor="middle">{point.label.length > 11 ? `${point.label.slice(0, 9)}…` : point.label}</text></g>)}
    </svg>
  </ChartShell>;
});

export const BarChart = memo(function BarChart({ title, subtitle, points, unit = '' }: { title: string; subtitle: string; points: ChartPoint[]; unit?: string }) {
  if (!points.length) return <ChartShell title={title} subtitle={subtitle}><ChartEmpty /></ChartShell>;
  const maximum = Math.max(...points.map((point) => point.value), 1);
  return <ChartShell title={title} subtitle={subtitle}>
    <div className="exec-bar-chart" role="img" aria-label={`${title}: ${points.map((point) => `${point.label} ${point.value}${unit}`).join(', ')}`}>
      {points.map((point) => <div className="exec-bar-column" key={point.label}>
        <span>{point.value.toLocaleString('es-DO', { maximumFractionDigits: 2 })}{unit}</span>
        <div><i style={{ height: `${Math.max((point.value / maximum) * 100, point.value > 0 ? 4 : 0)}%` }} /></div>
        <small>{point.label.length > 13 ? `${point.label.slice(0, 11)}…` : point.label}</small>
      </div>)}
    </div>
  </ChartShell>;
});

function ChartShell({ title, subtitle, children }: { title: string; subtitle: string; children: ReactNode }) {
  return <section className="exec-chart-card"><header><div><span>ANÁLISIS</span><h2>{title}</h2><p>{subtitle}</p></div></header>{children}</section>;
}

function ChartEmpty() {
  return <div className="exec-chart-empty"><div><i /><i /><i /><i /></div><b>Sin histórico suficiente</b><span>La gráfica aparecerá cuando existan al menos dos puntos reales.</span></div>;
}

export function DashboardFilters({
  value,
  onChange,
  onApply,
  onClear,
  branches,
  departments,
  employees,
}: {
  value: ReportFiltersValue;
  onChange: (value: ReportFiltersValue) => void;
  onApply: () => void;
  onClear: () => void;
  branches: DashboardFilterOption[];
  departments: DashboardFilterOption[];
  employees: DashboardFilterOption[];
}) {
  const employeeListId = useId().replace(/:/g, '');
  const updateSelect = (key: keyof ReportFiltersValue, nextValue: string) => {
    if (key === 'branch') return onChange({ ...value, branch: nextValue, department: '', employee: '' });
    if (key === 'department') return onChange({ ...value, department: nextValue, employee: '' });
    onChange({ ...value, [key]: nextValue });
  };
  const select = (key: keyof ReportFiltersValue, label: string, options: DashboardFilterOption[], disabled = false, allowAll = true) => <label>
    <span>{label}</span>
    <select aria-label={label} value={value[key]} disabled={disabled} onChange={(event) => updateSelect(key, event.target.value)}>
      {(allowAll || disabled) && <option value="">{disabled ? 'No disponible en los datos actuales' : `Todos · ${label}`}</option>}
      {options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
    </select>
  </label>;
  const submit = (event: FormEvent) => { event.preventDefault(); onApply(); };
  return <form className="exec-filters" aria-label="Filtros del Dashboard ejecutivo" onSubmit={submit}>
    <header><div><Filter /><div><b>Filtros ejecutivos</b><span>Refina los indicadores sin modificar los datos de origen.</span></div></div><span>Vista actual</span></header>
    <div className="exec-filter-grid">
      {select('company', 'Empresa', [{ value: 'current', label: 'Empresa autenticada' }], false, false)}
      {select('branch', 'Sucursal', branches)}
      {select('department', 'Departamento', departments)}
      {select('supervisor', 'Supervisor', [], true)}
      <label><span>Empleado</span><input aria-label="Empleado" type="search" list={employeeListId} value={value.employee} placeholder="Código o nombre" onChange={(event) => onChange({ ...value, employee: event.target.value })} /><datalist id={employeeListId}>{employees.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</datalist></label>
      <label><span>Desde</span><input aria-label="Desde" type="date" value={value.from} onChange={(event) => onChange({ ...value, from: event.target.value })} /></label>
      <label><span>Hasta</span><input aria-label="Hasta" type="date" value={value.to} onChange={(event) => onChange({ ...value, to: event.target.value })} /></label>
      <div className="exec-filter-actions"><button type="submit" className="primary"><Check />Aplicar filtros</button><button type="button" className="secondary" onClick={onClear}><RotateCcw />Limpiar</button></div>
    </div>
  </form>;
}

export function DashboardSkeleton() {
  return <div className="exec-skeleton" role="status" aria-busy="true"><span className="sr-only">Cargando Dashboard Ejecutivo</span>
    <div className="exec-skeleton-hero"><i /><i /><i /></div>
    <div className="exec-skeleton-grid">{Array.from({ length: 5 }, (_, index) => <article key={index}><i /><i /><i /></article>)}</div>
    <div className="exec-skeleton-wide"><article /><article /><article /></div>
  </div>;
}
