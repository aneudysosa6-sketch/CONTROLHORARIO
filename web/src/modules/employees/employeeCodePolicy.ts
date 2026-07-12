export const EMPLOYEE_CODE_LENGTH=5;
export const EMPLOYEE_CODE_ERROR='El código debe contener exactamente 5 dígitos.';
export const sanitizeEmployeeCode=(value:string)=>value.replace(/\D/g,'').slice(0,EMPLOYEE_CODE_LENGTH);
export const isValidEmployeeCode=(value:string)=>/^\d{5}$/.test(value);
