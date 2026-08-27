import type{Employee}from'../types';
import{employees as seed}from'../data/mockData';
const EMPLOYEES='osinet_employees';
const wait=(ms=180)=>new Promise(r=>setTimeout(r,ms));
export const employeeService={async list():Promise<Employee[]>{await wait();const saved=localStorage.getItem(EMPLOYEES);return saved?JSON.parse(saved):seed},async save(employee:Employee){const all=await this.list();const index=all.findIndex(e=>e.id===employee.id);index>=0?all[index]=employee:all.unshift({...employee,new:true});localStorage.setItem(EMPLOYEES,JSON.stringify(all))},async remove(id:string){const all=await this.list();localStorage.setItem(EMPLOYEES,JSON.stringify(all.filter(e=>e.id!==id)))}};
