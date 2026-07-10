export type EmployeeStatus = 'Activo' | 'Inactivo';
export type WorkState = 'Trabajando' | 'En pausa' | 'Ausente' | 'Finalizada';
export interface Employee { id:string; code:string; pin:string; name:string; initials:string; cedula:string; role:string; department:string; branch:string; phone:string; email:string; startDate:string; status:EmployeeStatus; salary:number; payType:string; schedule:string; workState:WorkState; new?:boolean }
export interface Attendance { id:string; employeeId:string; employee:string; action:'Inicio'|'Pausa'|'Reanudación'|'Fin'; date:string; time:string; location:string; new?:boolean }
export interface PayrollRow { id:string; employee:string; hours:number; overtime:number; deductions:number; gross:number; net:number }
export interface Session { username:string; name:string; role:string }
