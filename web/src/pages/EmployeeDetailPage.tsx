import { useEffect, useState } from 'react';
import { ArrowLeft, Fingerprint, Pencil, RotateCcw, UserMinus } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { Badge, PageHeader, Toast } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { EmployeeLifecycleDialog, type EmployeeLifecycleMode } from '../modules/employees/EmployeeLifecycleDialog';
import { employeeService, type EmployeePaySheet, type EmployeeRecord } from '../modules/employees/employeeService';
import { employeePayRates } from '../modules/employees/employeePayCalculations';

const money = (value: number) => `RD$ ${Number(value ?? 0).toLocaleString('es-DO', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export function EmployeeDetailPage() {
  const { id = '' } = useParams();
  const { hasPermission } = useAuth();
  const [employee, setEmployee] = useState<EmployeeRecord | null>();
  const [pay, setPay] = useState<EmployeePaySheet | null>(null);
  const [lifecycleMode, setLifecycleMode] = useState<EmployeeLifecycleMode | null>(null);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    const [nextEmployee, nextPay] = await Promise.all([employeeService.get(id), employeeService.getPay(id)]);
    setEmployee(nextEmployee);
    setPay(nextPay);
  };

  useEffect(() => {
    load().catch((failure) => setError(failure instanceof Error ? failure.message : 'No fue posible cargar el empleado.'));
  }, [id]);

  if (error) return <div className="error">{error}</div>;
  if (employee === undefined || pay === null) return <div className="empty">Cargando empleado…</div>;
  if (employee === null) return <div className="empty">Empleado no encontrado o fuera de tu alcance RLS.</div>;

  const rates = employeePayRates(employee.salary, pay.config.dias_divisor_quincenal, pay.config.horas_dia);
  const terminated = employee.status === 'desvinculado';
  const canChangeLifecycle = hasPermission('empleados.desactivar');

  return <>
    <PageHeader
      eyebrow={`EXPEDIENTE ${employee.code}`}
      title={employee.name}
      description={`${employee.positionName || 'Sin cargo'} · ${employee.departmentName || 'Sin departamento'}`}
      action={<div className="button-row">
        <Link className="secondary" to={terminated ? '/empleados/bajas' : '/empleados'}><ArrowLeft />Volver</Link>
        {!terminated && <Link className="primary" to={`/empleados/${employee.id}/editar`}><Pencil />Editar</Link>}
      </div>}
    />
    <section className="profile panel">
      <div className="profile-head">
        <span className="avatar big">{employee.name.split(' ').map((part) => part[0]).join('').slice(0, 2).toUpperCase()}</span>
        <div><h2>{employee.name}</h2><Badge tone={terminated ? 'gray' : employee.active ? 'green' : 'amber'}>{employee.status}</Badge></div>
        {canChangeLifecycle && <button className={terminated ? 'primary' : 'secondary'} type="button" onClick={() => setLifecycleMode(terminated ? 'reactivate' : 'terminate')}>
          {terminated ? <RotateCcw /> : <UserMinus />}{terminated ? 'Reactivar' : 'Dar de baja'}
        </button>}
      </div>
      <div className="detail-grid">
        {[
          ['Código de empleado', employee.code], ['Cédula', employee.cedula], ['Teléfono', employee.phone],
          ['Correo', employee.email], ['Sucursal', employee.branchName], ['Ingreso', employee.startDate],
          ['Departamento', employee.departmentName], ['Cargo', employee.positionName],
        ].map(([key, value]) => <div key={key}><small>{key}</small><b>{value || 'No registrado'}</b></div>)}
      </div>
    </section>
    {terminated && <section className="panel" style={{ marginTop: 16 }}>
      <div className="panel-title"><div><span className="eyebrow">DESVINCULACIÓN</span><h2>Datos de la baja laboral</h2></div><Badge tone="gray">Historial conservado</Badge></div>
      <div className="detail-grid">
        <div><small>Fecha</small><b>{employee.terminationDate || 'No registrada'}</b></div>
        <div><small>Motivo</small><b>{employee.terminationReason || 'No registrado'}</b></div>
        <div><small>Observación</small><b>{employee.terminationObservation || 'Sin observación'}</b></div>
        <div><small>Responsable</small><b>{employee.terminationActorName || 'No registrado (histórico)'}</b></div>
      </div>
    </section>}
    <section className="panel" style={{ marginTop: 16 }}>
      <div className="panel-title"><div><span className="eyebrow">PAGO Y NÓMINA</span><h2>Configuración salarial del empleado</h2></div><Badge tone={pay.config.nomina_activa ? 'green' : 'gray'}>{pay.config.nomina_activa ? 'Activa' : 'Inactiva'}</Badge></div>
      <div className="detail-grid">{[
        ['Sueldo mensual', money(employee.salary ?? 0)], ['Divisor', pay.config.dias_divisor_quincenal],
        ['Horas normales diarias', pay.config.horas_dia], ['Pago diario', money(rates.daily)],
        ['Valor hora normal', money(rates.hourly)], ['Valor hora extra manual', money(pay.config.valor_hora_extra)],
        ['Pago por 8 horas', money(rates.eightHours)], ['Incentivo fijo', money(pay.config.incentivo_periodo)],
        ['AFP por quincena', money(pay.config.afp_valor)], ['SFS por quincena', money(pay.config.sfs_valor)],
        ['Otros impuestos', money(pay.config.otros_impuestos_valor)],
        ['Descuento fijo', pay.config.descuento_fijo_activo ? money(pay.config.descuento_fijo_quincenal) : 'Inactivo'],
        ['Motivo descuento', pay.config.descuento_fijo_motivo || '—'], ['Otros descuentos', money(pay.config.otros_descuentos_fijos)],
      ].map(([key, value]) => <div key={key}><small>{key}</small><b>{value}</b></div>)}</div>
    </section>
    {([['Préstamos', pay.prestamos], ['Créditos', pay.creditos]] as const).map(([title, items]) => <section className="panel" style={{ marginTop: 16 }} key={title}>
      <div className="panel-title"><h2>{title}</h2></div>
      {items.length ? <div className="detail-grid">{items.map((item) => <div key={item.id}><small>{item.estado} · cuota {money(item.descuento_periodo)}</small><b>Pendiente {money(item.pendiente)} de {money(item.monto_total)}</b><p>{item.motivo}</p></div>)}</div> : <p>No hay {title.toLowerCase()} registrados.</p>}
    </section>)}
    <section className="panel" style={{ marginTop: 16 }}>
      <div className="panel-title"><div><span className="eyebrow">BIOMETRÍA FACIAL</span><h2>Rostro registrado</h2></div><Badge tone={employee.fingerprintReady ? 'green' : 'gray'}>{employee.fingerprintReady ? 'Registrada' : 'Sin registrar'}</Badge></div>
      <p>{employee.fingerprintRegisteredAt ? `Último registro: ${new Date(employee.fingerprintRegisteredAt).toLocaleString('es-DO')}. ` : ''}{employee.fingerprintDevice ? `Dispositivo: ${employee.fingerprintDevice}. ` : ''}La web nunca recibe ni muestra el template biométrico.</p>
      <button className="secondary" disabled><Fingerprint />Registrar rostro en Android</button>
    </section>
    {lifecycleMode && <EmployeeLifecycleDialog
      employee={employee}
      mode={lifecycleMode}
      onCancel={() => setLifecycleMode(null)}
      onCompleted={async (nextMessage) => {
        setLifecycleMode(null);
        setMessage(nextMessage);
        await load();
      }}
    />}
    <Toast message={message} />
  </>;
}
