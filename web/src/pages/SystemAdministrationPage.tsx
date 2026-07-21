import{useEffect,useMemo,useState,type FormEvent,type ReactNode}from'react';
import{Activity,ArrowLeft,Building2,CalendarClock,ChevronRight,ContactRound,GitBranch,KeyRound,MonitorCog,Palette,ShieldCheck,Smartphone,UsersRound}from'lucide-react';
import{Link,useNavigate}from'react-router-dom';
import{Badge,Empty,PageHeader,Toast}from'../components/UI';
import{useAuth}from'../context/AuthContext';
import{AdministrationError,administrationService,type AdminSection,type AdministrationOverview,type Appearance,type AuditEvent,type Branch,type Department,type OrganizationData,type Position,type Schedule}from'../modules/administration/administrationService';

const cards:{key:AdminSection;title:string;description:string;icon:(p:{size?:number})=>ReactNode;count?:keyof AdministrationOverview['counts']}[]=[
 {key:'empresa',title:'Empresa',description:'Identidad, logo, RNC, contacto y zona horaria.',icon:Building2},
 {key:'sucursales',title:'Sucursales',description:'Ubicaciones, contacto, zona horaria y estado.',icon:GitBranch,count:'branches'},
 {key:'departamentos',title:'Departamentos',description:'Estructura por sucursal y supervisores asignados.',icon:UsersRound,count:'departments'},
 {key:'cargos',title:'Cargos',description:'Cargos laborales por departamento y estado.',icon:ContactRound,count:'positions'},
 {key:'usuarios',title:'Accesos',description:'Credenciales vinculadas a empleados, roles y permisos.',icon:KeyRound,count:'profiles'},
 {key:'horarios',title:'Horarios',description:'Turnos, días, almuerzo y tolerancia.',icon:CalendarClock,count:'schedules'},
 {key:'jornadas',title:'Jornadas',description:'Pendientes, incidencias y reglas operativas.',icon:Activity,count:'pending_journeys'},
 {key:'dispositivos',title:'Dispositivos',description:'Android registrados, sincronización y revocación.',icon:Smartphone,count:'devices'},
 {key:'seguridad',title:'Seguridad',description:'Sesión actual, auditoría y accesos.',icon:ShieldCheck,count:'audit_events'},
 {key:'apariencia',title:'Apariencia',description:'Tema, colores y densidad visual.',icon:Palette},
];
const emptyOrg:OrganizationData={branches:[],departments:[],positions:[],profiles:[],employees:[],roles:[],permissions:[],departmentAssignments:[],rolePermissions:[]};
const errorText=(error:unknown)=>error instanceof AdministrationError?error.visible():error instanceof Error?error.message:'Error desconocido de administración.';
const defaultBranch={name:'',code:'',address:'',phone:'',email:'',timezone:'',status:'active'};
const defaultDepartment={name:'',code:'',branch_id:'',description:'',is_active:true,supervisor:''};
const defaultPosition={name:'',code:'',department_id:'',description:'',level:1,is_active:true};

export function SystemAdministrationPage({section}: {section?:AdminSection}){
 const nav=useNavigate(),{hasPermission}=useAuth();const[overview,setOverview]=useState<AdministrationOverview|null>(null),[organization,setOrganization]=useState<OrganizationData>(emptyOrg),[schedules,setSchedules]=useState<Schedule[]>([]),[audit,setAudit]=useState<AuditEvent[]>([]),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 async function load(){setLoading(true);setError('');try{const summary=await administrationService.overview();setOverview(summary);if(section&&['sucursales','departamentos','cargos','usuarios','horarios'].includes(section))setOrganization(await administrationService.organization());if(section==='horarios')setSchedules(await administrationService.schedules());if(section==='seguridad')setAudit(await administrationService.audit())}catch(e){setError(errorText(e))}finally{setLoading(false)}}
 useEffect(()=>{void load()},[section]);
 async function run(action:()=>Promise<unknown>,ok:string){setBusy(true);setError('');try{await action();setMessage(ok);await load();return true}catch(e){setError(errorText(e));return false}finally{setBusy(false)}}
 if(loading)return <Empty text="Cargando datos reales de la empresa…"/>;
 if(!overview)return <><PageHeader eyebrow="ADMINISTRACIÓN" title="Administración del sistema" description="No fue posible cargar el contexto administrativo."/>{error&&<div className="error admin-error">{error}</div>}</>;
 if(!section)return <AdministrationHub overview={overview}/>;
 if(!overview.sections[section])return <AdminShell title={cards.find(x=>x.key===section)?.title??section} onBack={()=>nav('/administracion')}><div className="error">Permisos insuficientes para abrir este módulo. La navegación administrativa permanece disponible.</div></AdminShell>;
 const common={overview,organization,busy,run};
 return <>{error&&<div className="error admin-floating-error"><b>Error real de Supabase</b><span>{error}</span></div>}{section==='empresa'&&<CompanySection {...common}/>} {section==='sucursales'&&<BranchesSection {...common}/>} {section==='departamentos'&&<DepartmentsSection {...common}/>} {section==='cargos'&&<PositionsSection {...common}/>} {section==='usuarios'&&<UsersSection {...common} hasPermission={hasPermission}/>} {section==='horarios'&&<SchedulesSection schedules={schedules} organization={organization}/>} {section==='jornadas'&&<JourneysSection overview={overview}/>} {section==='seguridad'&&<SecuritySection overview={overview} audit={audit}/>} {section==='apariencia'&&<AppearanceSection {...common}/>}<Toast message={message}/></>;
}

function AdministrationHub({overview}:{overview:AdministrationOverview}){return <><PageHeader eyebrow="CONTROL CENTRAL" title="Administración del sistema" description={`${overview.company.name} · Configuración segura por permisos efectivos y aislamiento multiempresa.`}/><section className="admin-cards">{cards.filter(c=>overview.sections[c.key]).map(({key,title,description,icon:Icon,count})=><Link className="admin-card panel" to={key==='usuarios'?'/accesos':`/administracion/${key}`} key={key}><span className="admin-card-icon"><Icon size={22}/></span><div><h2>{title}</h2><p>{description}</p>{count&&<Badge tone="blue">{overview.counts[count]} registros</Badge>}</div><ChevronRight/></Link>)}</section></>}
function AdminShell({title,children,action}:{title:string;children:ReactNode;action?:ReactNode;onBack?:()=>void}){return <><PageHeader eyebrow="ADMINISTRACIÓN DEL SISTEMA" title={title} description="Datos reales de la empresa autenticada y operaciones protegidas por permisos." action={<div className="button-row"><Link className="secondary" to="/administracion"><ArrowLeft/>Administración</Link>{action}</div>}/>{children}</>}

type Common={overview:AdministrationOverview;organization:OrganizationData;busy:boolean;run:(action:()=>Promise<unknown>,ok:string)=>Promise<boolean>};
function CompanySection({overview,busy,run}:Common){const c=overview.company,[form,setForm]=useState({name:c.name,legal_name:c.legal_name??'',tax_id:c.tax_id??'',logo_url:c.logo_url??'',address:c.address??'',email:c.email??'',phone:c.phone??'',timezone:c.timezone}),[reason,setReason]=useState('');return <AdminShell title="Empresa"><form className="panel admin-form" onSubmit={e=>{e.preventDefault();void run(()=>administrationService.updateCompany(form,reason),'Datos de empresa actualizados')}}><label>Nombre comercial<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Razón social<input value={form.legal_name} onChange={e=>setForm(v=>({...v,legal_name:e.target.value}))}/></label><label>RNC<input value={form.tax_id} onChange={e=>setForm(v=>({...v,tax_id:e.target.value}))}/></label><label>Logo URL<input type="url" value={form.logo_url} onChange={e=>setForm(v=>({...v,logo_url:e.target.value}))}/></label><label className="span-2">Dirección<input value={form.address} onChange={e=>setForm(v=>({...v,address:e.target.value}))}/></label><label>Correo<input type="email" value={form.email} onChange={e=>setForm(v=>({...v,email:e.target.value}))}/></label><label>Teléfono<input value={form.phone} onChange={e=>setForm(v=>({...v,phone:e.target.value}))}/></label><label>Zona horaria<input value={form.timezone} onChange={e=>setForm(v=>({...v,timezone:e.target.value}))} required/></label><label>Motivo del cambio<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar cambios</button></form></AdminShell>}

function BranchesSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultBranch),[reason,setReason]=useState('');function edit(x:Branch){setEditing(x.id);setForm({name:x.name,code:x.code,address:x.address??'',phone:x.phone??'',email:x.email??'',timezone:x.timezone??'',status:x.status})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveBranch(editing,form,reason),editing?'Sucursal actualizada':'Sucursal creada')){setEditing(null);setForm(defaultBranch);setReason('')}}return <AdminShell title="Sucursales"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar sucursal':'Nueva sucursal'}</h2>{(['name','code','address','phone','email','timezone']as const).map(k=><label key={k}>{({name:'Nombre',code:'Código',address:'Dirección',phone:'Teléfono',email:'Correo',timezone:'Zona horaria'})[k]}<input type={k==='email'?'email':'text'} value={form[k]} onChange={e=>setForm(v=>({...v,[k]:e.target.value}))} required={k==='name'||k==='code'}/></label>)}<label>Estado<select value={form.status} onChange={e=>setForm(v=>({...v,status:e.target.value}))}><option value="active">Activa</option><option value="inactive">Inactiva</option></select></label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Sucursal','Contacto','Zona/estado','']} rows={organization.branches.map(x=>[x.code,x.name,<small>{x.phone||'—'} · {x.email||'—'}</small>,<><Badge tone={x.status==='active'?'green':'gray'}>{x.status}</Badge><small>{x.timezone||'Hereda empresa'}</small></>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function DepartmentsSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultDepartment),[reason,setReason]=useState('');const supervisors=organization.profiles.filter(p=>organization.roles.find(r=>r.id===p.role_id)?.code==='supervisor');function edit(x:Department){setEditing(x.id);setForm({name:x.name,code:x.code,branch_id:x.branch_id??'',description:x.description??'',is_active:x.is_active,supervisor:organization.departmentAssignments.find(a=>a.departamento_id===x.id)?.perfil_id??''})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveDepartment(editing,form,form.supervisor||null,reason),editing?'Departamento actualizado':'Departamento creado')){setEditing(null);setForm(defaultDepartment);setReason('')}}return <AdminShell title="Departamentos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar departamento':'Nuevo departamento'}</h2><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Código<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Sucursal<select value={form.branch_id} onChange={e=>setForm(v=>({...v,branch_id:e.target.value}))}><option value="">Corporativo</option>{organization.branches.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Supervisor<select value={form.supervisor} onChange={e=>setForm(v=>({...v,supervisor:e.target.value}))}><option value="">Sin asignar</option>{supervisors.map(x=><option key={x.id} value={x.id}>{x.full_name}</option>)}</select></label><label>Descripción<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Departamento','Sucursal','Supervisor','']} rows={organization.departments.map(x=>{const assignment=organization.departmentAssignments.find(a=>a.departamento_id===x.id);return[x.code,x.name,organization.branches.find(b=>b.id===x.branch_id)?.name??'Corporativo',organization.profiles.find(p=>p.id===assignment?.perfil_id)?.full_name??'Sin asignar',<button className="secondary" onClick={()=>edit(x)}>Editar</button>]})}/>}/></AdminShell>}

function PositionsSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultPosition),[reason,setReason]=useState('');function edit(x:Position){setEditing(x.id);setForm({name:x.name,code:x.code,department_id:x.department_id??'',description:x.description??'',level:x.level,is_active:x.is_active})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.savePosition(editing,form,reason),editing?'Cargo actualizado':'Cargo creado')){setEditing(null);setForm(defaultPosition);setReason('')}}return <AdminShell title="Cargos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar cargo':'Nuevo cargo'}</h2><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Código<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Departamento<select value={form.department_id} onChange={e=>setForm(v=>({...v,department_id:e.target.value}))}><option value="">General</option>{organization.departments.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Nivel<input type="number" min="1" max="20" value={form.level} onChange={e=>setForm(v=>({...v,level:Number(e.target.value)}))}/></label><label>Descripción<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Cargo','Departamento','Estado','']} rows={organization.positions.map(x=>[x.code,x.name,organization.departments.find(d=>d.id===x.department_id)?.name??'General',<Badge tone={x.is_active?'green':'gray'}>{x.is_active?'Activo':'Inactivo'}</Badge>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function UsersSection({
  organization,
  busy,
  run,
  hasPermission,
}: Common & {
  hasPermission: (permission: string) => boolean;
}) {
  const [reason, setReason] = useState('');
  const [editingRoleId, setEditingRoleId] = useState<string | null>(null);
  const [roleForm, setRoleForm] = useState({
    name: '',
    code: '',
    description: '',
    isActive: true,
  });
  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([]);

  const canManageRoles = hasPermission('roles.administrar');
  const canManagePermissions = hasPermission('permisos.administrar');
  const editingRole = organization.roles.find(
    (role) => role.id === editingRoleId,
  );

  function isAdministratorRole(role: { code: string; name: string }) {
    const normalized = `${role.code} ${role.name}`
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toUpperCase()
      .replace(/[^A-Z]/g, '');

    return (
      normalized.includes('ADMIN') ||
      normalized.includes('ADMINISTRADOR') ||
      normalized.includes('ADMINISTRATOR')
    );
  }

  function rolePermissionIds(roleId: string) {
    return organization.rolePermissions
      .filter(
        (rolePermission) =>
          rolePermission.rol_id === roleId && rolePermission.permitido,
      )
      .map((rolePermission) => rolePermission.permiso_id);
  }

  function assignedUsers(roleId: string) {
    return organization.profiles.filter((profile) => profile.role_id === roleId);
  }

  function resetRoleForm() {
    setEditingRoleId(null);
    setRoleForm({
      name: '',
      code: '',
      description: '',
      isActive: true,
    });
    setSelectedPermissions([]);
  }

  function editRole(role: {
    id: string;
    name: string;
    code: string;
    description: string | null;
    is_active: boolean;
  }) {
    setEditingRoleId(role.id);
    setRoleForm({
      name: role.name,
      code: role.code,
      description: role.description ?? '',
      isActive: role.is_active,
    });
    setSelectedPermissions(rolePermissionIds(role.id));
  }

  async function saveRole(event: FormEvent) {
    event.preventDefault();

    if (
      busy ||
      !roleForm.name.trim() ||
      !roleForm.code.trim() ||
      (editingRoleId !== null && !reason.trim())
    ) {
      return;
    }

    const created = editingRoleId === null;
    const saved = await run(async () => {
      const roleId = await administrationService.saveRole(
        editingRoleId,
        roleForm.name,
        roleForm.code,
        roleForm.description,
        roleForm.isActive,
        created ? '' : reason,
      );
      const previousPermissions = new Set(
        editingRoleId ? rolePermissionIds(editingRoleId) : [],
      );
      const nextPermissions = new Set(selectedPermissions);
      const permissionReason = created
        ? 'Creación inicial del rol'
        : reason;

      for (const permission of organization.permissions) {
        const wasAssigned = previousPermissions.has(permission.id);
        const isAssigned = nextPermissions.has(permission.id);

        if (wasAssigned !== isAssigned) {
          await administrationService.setRolePermission(
            roleId,
            permission.id,
            isAssigned,
            permissionReason,
          );
        }
      }
    }, created ? 'Rol creado' : 'Rol actualizado');

    if (saved) {
      resetRoleForm();
    }
  }

  async function toggleRoleStatus(role: {
    id: string;
    name: string;
    code: string;
    description: string | null;
    is_active: boolean;
  }) {
    if (!reason.trim()) return;

    const users = assignedUsers(role.id);
    const deactivating = role.is_active;

    if (deactivating && isAdministratorRole(role)) return;
    if (deactivating && users.length > 0) return;

    const action = deactivating ? 'desactivar' : 'activar';
    if (
      !window.confirm(
        `¿Confirmas ${action} el rol "${role.name}"? Esta acción quedará auditada.`,
      )
    ) {
      return;
    }

    await run(
      () =>
        administrationService.saveRole(
          role.id,
          role.name,
          role.code,
          role.description ?? '',
          !deactivating,
          reason,
        ),
      deactivating ? 'Rol desactivado' : 'Rol activado',
    );
  }

  function togglePermission(permissionId: string, checked: boolean) {
    setSelectedPermissions((current) =>
      checked
        ? [...current, permissionId]
        : current.filter((id) => id !== permissionId),
    );
  }

  return (
    <AdminShell title="Roles y permisos">
      <div className="admin-users-actions">
        {hasPermission('usuarios.administrar') && (
          <Link className="primary" to="/accesos">
            Administrar accesos
          </Link>
        )}

        <label>
          Motivo para cambios
          <input
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder="Obligatorio para editar, permisos y estado"
          />
        </label>
      </div>

      {canManageRoles && (
        <>
          <section className="panel admin-role-panel">
            <form
              className="admin-inline-form"
              onSubmit={(event) => void saveRole(event)}
            >
              <h2>{editingRoleId ? 'Editar rol' : 'Nuevo rol'}</h2>

              <input
                placeholder="Nombre"
                value={roleForm.name}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    name: event.target.value,
                  }))
                }
                required
              />
              <input
                placeholder="Código"
                value={roleForm.code}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    code: event.target.value,
                  }))
                }
                required
                readOnly={editingRoleId !== null}
                title={
                  editingRoleId
                    ? 'El código técnico del rol no se modifica.'
                    : undefined
                }
              />
              <input
                placeholder="Descripción"
                value={roleForm.description}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    description: event.target.value,
                  }))
                }
              />

              <button
                className="primary"
                disabled={
                  busy ||
                  !roleForm.name.trim() ||
                  !roleForm.code.trim() ||
                  (editingRoleId !== null && !reason.trim())
                }
              >
                {busy
                  ? 'Guardando…'
                  : editingRoleId
                    ? 'Guardar cambios'
                    : 'Crear rol'}
              </button>
              {editingRoleId && (
                <button
                  type="button"
                  className="secondary"
                  disabled={busy}
                  onClick={resetRoleForm}
                >
                  Cancelar edición
                </button>
              )}
            </form>

            {canManagePermissions && (
              <div className="admin-permission-grid">
                <h3>
                  {editingRoleId
                    ? 'Permisos del rol'
                    : 'Permisos iniciales del rol'}
                </h3>
                {organization.permissions.map((permission) => (
                  <label key={permission.id}>
                    <input
                      type="checkbox"
                      checked={selectedPermissions.includes(permission.id)}
                      disabled={busy || (editingRoleId !== null && !reason)}
                      onChange={(event) =>
                        togglePermission(permission.id, event.target.checked)
                      }
                    />
                    {permission.nombre || permission.codigo}
                  </label>
                ))}
                {editingRoleId && !reason.trim() && (
                  <small>
                    Escribe el motivo para modificar los permisos del rol.
                  </small>
                )}
              </div>
            )}
          </section>

          <section className="panel admin-role-panel">
            <h2>Roles existentes</h2>
            <SimpleTable
              headers={[
                'Nombre',
                'Código',
                'Descripción',
                'Estado',
                'Permisos',
                'Acciones',
              ]}
              rows={organization.roles.map((role) => {
                const users = assignedUsers(role.id);
                const isPrimaryAdministrator = isAdministratorRole(role);
                const canDeactivate =
                  role.is_active &&
                  !isPrimaryAdministrator &&
                  users.length === 0;
                const actionDisabled =
                  busy ||
                  !reason.trim() ||
                  (role.is_active && !canDeactivate);

                return [
                  role.name,
                  <code key={`${role.id}-code`}>{role.code}</code>,
                  role.description || '—',
                  <Badge
                    key={`${role.id}-status`}
                    tone={role.is_active ? 'green' : 'gray'}
                  >
                    {role.is_active ? 'Activo' : 'Inactivo'}
                  </Badge>,
                  `${rolePermissionIds(role.id).length} permiso(s)`,
                  <div key={`${role.id}-actions`} className="button-row">
                    <button
                      className="secondary"
                      disabled={busy}
                      onClick={() => editRole(role)}
                    >
                      Editar
                    </button>
                    <button
                      className="secondary"
                      disabled={actionDisabled}
                      title={
                        isPrimaryAdministrator && role.is_active
                          ? 'El rol Administrador principal no se puede desactivar.'
                          : users.length > 0 && role.is_active
                            ? `Reasigna los ${users.length} usuario(s) antes de desactivar.`
                            : !reason.trim()
                              ? 'Escribe el motivo para cambiar el estado.'
                              : undefined
                      }
                      onClick={() => void toggleRoleStatus(role)}
                    >
                      {role.is_active ? 'Desactivar' : 'Activar'}
                    </button>
                    {users.length > 0 && (
                      <small>
                        {users.length} usuario(s) asignado(s): reasignación
                        requerida
                      </small>
                    )}
                  </div>,
                ];
              })}
            />
          </section>
        </>
      )}
    </AdminShell>
  );
}

function SchedulesSection({schedules,organization}:{schedules:Schedule[];organization:OrganizationData}){return <AdminShell title="Horarios" action={<Link className="primary" to="/supervisor/horarios">Gestionar horarios permitidos</Link>}><section className="stats admin-mini-stats"><article className="stat"><span>Turnos activos</span><strong>{schedules.filter(x=>x.activo).length}</strong></article><article className="stat"><span>Tolerancia configurada</span><strong>{schedules.length?`${Math.round(schedules.reduce((a,x)=>a+x.tolerancia_min,0)/schedules.length)} min`:'—'}</strong></article><article className="stat"><span>Almuerzo promedio</span><strong>{schedules.length?`${Math.round(schedules.reduce((a,x)=>a+x.duracion_almuerzo_min,0)/schedules.length)} min`:'—'}</strong></article></section><SimpleTable headers={['Empleado','Vigencia','Turno','Días','Tolerancia/almuerzo']} rows={schedules.map(x=>{const employee=organization.employees.find(e=>e.id===x.empleado_id);return[employee?`${employee.codigo_empleado} · ${employee.nombre_completo}`:x.empleado_id,`${x.fecha_vigencia}${x.fecha_fin?` → ${x.fecha_fin}`:''}`,`${x.hora_entrada}–${x.hora_salida}`,x.dias_laborales.join(', '),`${x.tolerancia_min} min / ${x.duracion_almuerzo_min} min`]})}/></AdminShell>}
function JourneysSection({overview}:{overview:AdministrationOverview}){return <AdminShell title="Jornadas" action={<Link className="primary" to="/jornadas">Abrir jornadas</Link>}><section className="stats admin-mini-stats"><article className="stat"><span>Pendientes de revisión</span><strong>{overview.counts.pending_journeys}</strong></article><article className="stat"><span>Reglas</span><strong>RC2</strong><small>Cierre e incidencias centralizados</small></article><article className="stat"><span>ADMIN-OFF/ON</span><strong>Protegido</strong><small>Requiere permiso explícito</small></article></section><div className="panel"><h2>Operación segura</h2><p>Las reglas, cierres automáticos, incidencias y pendientes se administran en el módulo real de Jornadas. Esta pantalla no duplica ni altera el motor RC2/RC3.</p><div className="button-row"><Link className="secondary" to="/supervisor/pendientes">Revisión de pendientes</Link><Link className="secondary" to="/supervisor/incidencias">Incidencias</Link></div></div></AdminShell>}
function SecuritySection({overview,audit}:{overview:AdministrationOverview;audit:AuditEvent[]}){return <AdminShell title="Seguridad" action={<Link className="primary" to="/cambiar-password">Cambiar contraseña</Link>}><section className="panel admin-session"><ShieldCheck/><div><h2>Sesión administrativa activa</h2><p>Usuario {overview.session.auth_uid} · Rol {overview.session.role} · Empresa {overview.company.name}</p><small>No se muestran tokens ni credenciales.</small></div></section><SimpleTable headers={['Fecha','Sección','Acción','Entidad','Motivo']} rows={audit.map(x=>[new Date(x.fecha).toLocaleString('es-DO'),x.seccion,x.accion,`${x.entidad}${x.entidad_id?` · ${x.entidad_id}`:''}`,x.motivo??'—'])}/>{!audit.length&&<Empty text="No hay eventos administrativos visibles para esta empresa."/>}</AdminShell>}
function AppearanceSection({overview,busy,run}:Common){const[form,setForm]=useState<Appearance>(overview.company.ui_preferences),[reason,setReason]=useState('');function setColor(key:'primary'|'accent',value:string){setForm(v=>({...v,[key]:value}))}return <AdminShell title="Apariencia"><form className="panel admin-form" onSubmit={e=>{e.preventDefault();void run(async()=>{await administrationService.updateAppearance(form,reason);document.documentElement.style.setProperty('--blue',form.primary);document.documentElement.style.setProperty('--green',form.accent)},'Preferencias visuales guardadas')}}><label>Tema<select value={form.theme} onChange={e=>setForm(v=>({...v,theme:e.target.value as Appearance['theme']}))}><option value="dark">Oscuro OSINET</option><option value="system">Según sistema</option></select></label><label>Densidad<select value={form.density} onChange={e=>setForm(v=>({...v,density:e.target.value as Appearance['density']}))}><option value="comfortable">Cómoda</option><option value="compact">Compacta</option></select></label><label>Azul corporativo<input type="color" value={form.primary} onChange={e=>setColor('primary',e.target.value)}/></label><label>Color de acento<input type="color" value={form.accent} onChange={e=>setColor('accent',e.target.value)}/></label><label>Logo URL<input value={overview.company.logo_url??''} disabled/><small>El logo se administra en Empresa.</small></label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar apariencia</button></form></AdminShell>}

function CrudLayout({form,table}:{form:ReactNode;table:ReactNode}){return <div className="admin-crud">{form}<section className="table-wrap">{table}</section></div>}
function SimpleTable({headers,rows}:{headers:string[];rows:ReactNode[][]}){return <div className="table-wrap"><table><thead><tr>{headers.map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={i}>{row.map((cell,j)=><td key={j}>{cell}</td>)}</tr>)}</tbody></table>{!rows.length&&<Empty text="No hay datos visibles para este alcance."/>}</div>}
