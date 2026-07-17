import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Empty, PageHeader } from '../components/UI';
import { employeeService, type EmployeePaySheet, type EmployeeRecord } from '../modules/employees/employeeService';
import { journeyService, type Journey } from '../modules/journeys/journeyService';

const money = (value: number) => new Intl.NumberFormat('es-DO', { style: 'currency', currency: 'DOP' }).format(value);

export function EmployeeHistoryPage() {
  const { id = '' } = useParams();
  const [employee, setEmployee] = useState<EmployeeRecord | null | undefined>();
  const [pay, setPay] = useState<EmployeePaySheet | null>(null);
  const [journeys, setJourneys] = useState<Journey[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    void Promise.all([employeeService.get(id), employeeService.getPay(id), journeyService.list()])
      .then(([current, sheet, rows]) => { setEmployee(current); setPay(sheet); setJourneys(rows.filter((journey) => journey.employeeId === id)); })
      .catch((reason) => setError(reason instanceof Error ? reason.message : 'No fue posible cargar el historial del empleado.'));
  }, [id]);

  if (error) return <div className="error">{error}</div>;
  if (employee === undefined) return <Empty text="Cargando historial del empleado…" />;
  if (!employee) return <Empty text="Empleado no encontrado o fuera del alcance autorizado." />;

  return <><PageHeader eyebrow="EMPLEADOS" title={`Historial de ${employee.name}`} description="Jornadas, incidencias y préstamos registrados; solo lectura." action={<Link className="secondary" to={`/empleados/${id}`}>Volver</Link>} /><section className="dashboard-grid"><section className="panel"><h2>Historial de jornadas</h2>{journeys.length ? journeys.map((journey) => <p key={journey.id}>{journey.workDate} · {journey.status} · {journey.workedMinutes} min trabajados.</p>) : <Empty text="No hay jornadas registradas." />}</section><section className="panel"><h2>Historial de incidencias</h2>{journeys.flatMap((journey) => journey.incidents).length ? journeys.flatMap((journey) => journey.incidents.map((incident) => <p key={incident.id}>{incident.createdAt} · {incident.type}: {incident.message}</p>)) : <Empty text="No hay incidencias registradas." />}</section><section className="panel"><h2>Historial de préstamos</h2>{pay?.prestamos.length ? pay.prestamos.map((loan) => <p key={loan.id}>{loan.estado} · Pagado {money(loan.total_pagado ?? 0)} · Pendiente {money(loan.pendiente)}</p>) : <Empty text="No hay préstamos registrados." />}</section><section className="panel"><h2>Configuración de nómina</h2>{pay ? <p>AFP: {money(pay.config.afp_valor)} · SFS: {money(pay.config.sfs_valor)} · Horas normales diarias: {pay.config.horas_dia}.</p> : <Empty text="No hay configuración de nómina disponible." />}</section></section></>;
}
