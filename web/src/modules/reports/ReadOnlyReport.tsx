import { useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { Empty, PageHeader } from '../../components/UI';
import { ReportFilters, type ReportFiltersValue } from './ReportFilters';

export const emptyReportFilters: ReportFiltersValue = { company: '', branch: '', department: '', supervisor: '', employee: '', from: '', to: '' };

export function ReadOnlyReport({ title, description, filters, onFiltersChange, summary, extraFilters, children }: { title: string; description: string; filters: ReportFiltersValue; onFiltersChange: (value: ReportFiltersValue) => void; summary: ReactNode; extraFilters?: ReactNode; children: ReactNode }) {
  return <><PageHeader eyebrow="REPORTES" title={title} description={description} action={<div className="button-row"><Link className="secondary" to="/reportes">Volver</Link><button className="secondary">Exportar PDF</button><button className="secondary">Exportar Excel</button><button className="secondary" onClick={() => window.print()}>Imprimir</button></div>} /><ReportFilters value={filters} onChange={onFiltersChange} />{extraFilters && <section className="panel payroll-periods">{extraFilters}</section>}<section className="stats payroll-stats">{summary}</section>{children}</>;
}

export function ReportStat({ label, value }: { label: string; value: ReactNode }) { return <article className="stat"><span>{label}</span><strong>{value}</strong></article>; }

export function ExpandableReportTable<T>({ rows, columns, detail, rowKey, empty }: { rows: T[]; columns: Array<{ label: string; value: (row: T) => ReactNode }>; detail: (row: T) => ReactNode; rowKey: (row: T) => string; empty: string }) {
  const [open, setOpen] = useState('');
  if (!rows.length) return <Empty text={empty} />;
  return <section className="table-wrap payroll-wide"><table><thead><tr>{columns.map((column) => <th key={column.label}>{column.label}</th>)}<th>Detalle</th></tr></thead><tbody>{rows.map((row) => { const key = rowKey(row); const expanded = key === open; return <><tr key={key}>{columns.map((column) => <td key={column.label}>{column.value(row)}</td>)}<td><button className="secondary" onClick={() => setOpen(expanded ? '' : key)}>{expanded ? 'Cerrar' : 'Abrir'}</button></td></tr>{expanded && <tr key={`${key}-detail`}><td colSpan={columns.length + 1}>{detail(row)}</td></tr>}</>; })}</tbody></table></section>;
}
