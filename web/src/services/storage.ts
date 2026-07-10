import type { Employee, Session } from '../types';
import { employees as seed } from '../data/mockData';
const EMPLOYEES='osinet_employees', SESSION='osinet_session';
const wait = (ms=180) => new Promise(r=>setTimeout(r,ms));
export const authService = {
 async login(username:string,password:string):Promise<Session>{ await wait(); if(username!=='admin' || password!=='Admin123!') throw new Error('Usuario o contraseña incorrectos'); const session={username,name:'María González',role:'Administradora'}; localStorage.setItem(SESSION,JSON.stringify(session)); return session; },
 getSession:():Session|null=>{ try{return JSON.parse(localStorage.getItem(SESSION)||'null')}catch{return null}},
 logout:()=>localStorage.removeItem(SESSION)
};
export const employeeService = {
 async list():Promise<Employee[]>{await wait(); const saved=localStorage.getItem(EMPLOYEES); return saved?JSON.parse(saved):seed;},
 async save(employee:Employee){const all=await this.list(); const index=all.findIndex(e=>e.id===employee.id); index>=0?all[index]=employee:all.unshift({...employee,new:true}); localStorage.setItem(EMPLOYEES,JSON.stringify(all));},
 async remove(id:string){const all=await this.list(); localStorage.setItem(EMPLOYEES,JSON.stringify(all.filter(e=>e.id!==id)));}
};
