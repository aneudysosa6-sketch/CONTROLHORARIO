import { useEffect, useMemo, useState } from 'react';
import { ArrowLeft, Eye, Play, Send, Volume2 } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { PageHeader } from '../components/UI';
import { useAuth } from '../context/AuthContext';
import { employeeService, type EmployeeRecord } from '../modules/employees/employeeService';
import {
  employeeMessageService,
  type EmployeeMessageType,
} from '../modules/messages/employeeMessageService';

const allowedStatus = (employee: EmployeeRecord) =>
  employee.active && ['activo', 'licencia', 'vacaciones'].includes(String(employee.status).toLowerCase());

function audioDuration(file: File): Promise<number> {
  return new Promise((resolve, reject) => {
    const source = URL.createObjectURL(file);
    const audio = new Audio();
    audio.preload = 'metadata';
    audio.onloadedmetadata = () => {
      URL.revokeObjectURL(source);
      Number.isFinite(audio.duration) ? resolve(Math.ceil(audio.duration)) : reject(new Error('Audio inválido.'));
    };
    audio.onerror = () => {
      URL.revokeObjectURL(source);
      reject(new Error('No fue posible leer el audio.'));
    };
    audio.src = source;
  });
}

export function EmployeeMessagesPage() {
  const { session } = useAuth();
  const navigate = useNavigate();
  const [employees, setEmployees] = useState<EmployeeRecord[]>([]);
  const [branchId, setBranchId] = useState('');
  const [departmentId, setDepartmentId] = useState('');
  const [employeeId, setEmployeeId] = useState('');
  const [type, setType] = useState<EmployeeMessageType>('TEXTO');
  const [text, setText] = useState('');
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [duration, setDuration] = useState(0);
  const [audioPreview, setAudioPreview] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [sent, setSent] = useState(false);

  useEffect(() => {
    employeeService.list()
      .then((rows) => setEmployees(rows.filter(allowedStatus)))
      .catch((reason) => setError(reason instanceof Error ? reason.message : 'No fue posible cargar empleados.'));
  }, []);

  useEffect(() => () => {
    if (audioPreview) URL.revokeObjectURL(audioPreview);
  }, [audioPreview]);

  const branches = useMemo(() => {
    const values = new Map<string, string>();
    employees.forEach((employee) => {
      if (employee.branchId) values.set(employee.branchId, employee.branchName || 'Sucursal');
    });
    return [...values.entries()];
  }, [employees]);

  const departments = useMemo(() => {
    const values = new Map<string, string>();
    employees.filter((employee) => employee.branchId === branchId).forEach((employee) => {
      if (employee.departmentId) values.set(employee.departmentId, employee.departmentName || 'Departamento');
    });
    return [...values.entries()];
  }, [employees, branchId]);

  const recipients = useMemo(
    () => employees.filter((employee) =>
      employee.branchId === branchId && employee.departmentId === departmentId),
    [employees, branchId, departmentId],
  );
  const selected = employees.find((employee) => employee.id === employeeId);

  async function selectAudio(file: File | null) {
    setError('');
    setAudioFile(null);
    setDuration(0);
    if (audioPreview) URL.revokeObjectURL(audioPreview);
    setAudioPreview('');
    if (!file) return;
    try {
      const seconds = await audioDuration(file);
      if (seconds < 1 || seconds > 30) throw new Error('La voz grabada debe durar entre 1 y 30 segundos.');
      setAudioFile(file);
      setDuration(seconds);
      setAudioPreview(URL.createObjectURL(file));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Audio inválido.');
    }
  }

  function playSystemVoice() {
    if (!text.trim() || !('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(new SpeechSynthesisUtterance(text));
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    if (!selected) return setError('Selecciona un empleado.');
    if (type !== 'VOZ_GRABADA' && !text.trim()) return setError('Escribe el mensaje.');
    if (type === 'VOZ_GRABADA' && (!audioFile || duration < 1 || duration > 30)) {
      return setError('Selecciona una grabación válida de hasta 30 segundos.');
    }
    const companyId = session?.companyId ?? '';
    if (!companyId) return setError('No se pudo resolver la empresa de la sesión.');

    setBusy(true);
    let uploadedPath: string | null = null;
    try {
      if (type === 'VOZ_GRABADA' && audioFile) {
        uploadedPath = await employeeMessageService.uploadAudio(companyId, audioFile);
      }
      await employeeMessageService.create({
        employeeId: selected.id,
        type,
        text: type === 'VOZ_GRABADA' ? null : text,
        audioObjectPath: uploadedPath,
        audioDurationSeconds: type === 'VOZ_GRABADA' ? duration : null,
        idempotencyKey: crypto.randomUUID(),
      });
      setSent(true);
      window.setTimeout(() => navigate('/administracion'), 3000);
    } catch (reason) {
      if (uploadedPath) await employeeMessageService.removeAudio(uploadedPath);
      const message = reason instanceof Error ? reason.message : 'No fue posible enviar el mensaje.';
      setError(message.includes('EMPLOYEE_MESSAGE_ALREADY_PENDING')
        ? 'ESTE EMPLEADO TIENE UN MENSAJE PENDIENTE'
        : message);
    } finally {
      setBusy(false);
    }
  }

  if (sent) {
    return <section className="process-success"><Send /><div><h2>✅ Mensaje enviado</h2><p>Volviendo a Administración…</p></div></section>;
  }

  return <>
    <PageHeader
      eyebrow="ADMINISTRACIÓN DEL SISTEMA"
      title="Mensajes a empleados"
      description="Un mensaje efímero se entrega después del próximo movimiento de jornada exitoso."
      action={<Link className="secondary" to="/administracion"><ArrowLeft />Administración</Link>}
    />
    {error && <div className="error">{error}</div>}
    <form className="form-panel" onSubmit={submit}>
      <section className="form-section">
        <h2>1. Destinatario</h2>
        <div className="form-grid">
          <label>Sucursal<select required value={branchId} onChange={(event) => {
            setBranchId(event.target.value); setDepartmentId(''); setEmployeeId('');
          }}><option value="">Seleccionar</option>{branches.map(([id, name]) =>
            <option key={id} value={id}>{name}</option>)}</select></label>
          <label>Departamento<select required value={departmentId} onChange={(event) => {
            setDepartmentId(event.target.value); setEmployeeId('');
          }}><option value="">Seleccionar</option>{departments.map(([id, name]) =>
            <option key={id} value={id}>{name}</option>)}</select></label>
          <label>Empleado<select required value={employeeId} onChange={(event) => setEmployeeId(event.target.value)}>
            <option value="">Seleccionar</option>{recipients.map((employee) =>
              <option key={employee.id} value={employee.id}>{employee.code} · {employee.name}</option>)}
          </select></label>
        </div>
      </section>

      <section className="form-section">
        <h2>2. Contenido</h2>
        <div className="form-grid">
          <label>Tipo<select value={type} onChange={(event) => {
            setType(event.target.value as EmployeeMessageType); setError('');
          }}>
            <option value="TEXTO">Texto</option>
            <option value="VOZ_SISTEMA">Voz del sistema</option>
            <option value="VOZ_GRABADA">Voz grabada</option>
          </select></label>
          {type === 'VOZ_GRABADA'
            ? <label>Grabación (máximo 30 s)<input type="file" accept="audio/*" onChange={(event) =>
              void selectAudio(event.target.files?.[0] ?? null)} /><small>{duration ? duration + ' segundos' : 'Sin grabación'}</small></label>
            : <label style={{gridColumn:'span 2'}}>Mensaje<textarea required value={text} onChange={(event) =>
              setText(event.target.value)} style={{minHeight:180,resize:'vertical',background:'#0b1728',color:'#eaf2ff',border:'1px solid #243956',borderRadius:8,padding:12}} /></label>}
        </div>
      </section>

      <section className="panel">
        <h2><Eye /> Vista previa</h2>
        <p><b>{selected?.name ?? 'Empleado sin seleccionar'}</b></p>
        {type === 'VOZ_GRABADA'
          ? audioPreview ? <audio controls src={audioPreview} /> : <p>Selecciona una grabación.</p>
          : <div style={{whiteSpace:'pre-wrap',maxHeight:260,overflowY:'auto'}}>{text || 'Escribe un mensaje.'}</div>}
        {type === 'VOZ_SISTEMA' && <button type="button" className="secondary" onClick={playSystemVoice}><Volume2 /><Play />Reproducir</button>}
      </section>

      <div className="form-actions"><button className="primary" disabled={busy || !selected} type="submit">
        <Send />{busy ? 'Enviando…' : 'Enviar mensaje'}
      </button></div>
    </form>
  </>;
}