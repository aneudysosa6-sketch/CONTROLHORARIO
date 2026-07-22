export const EMPLOYEE_CODE_LENGTH=6;
export const LEGACY_EMPLOYEE_CODE_LENGTH=5;
export const EMPLOYEE_CODE_ERROR='El código debe contener 5 o 6 dígitos.';

/** Keeps form input numeric without accepting an invalid value at an API boundary. */
export const sanitizeEmployeeCode=(value:string)=>value.replace(/\D/g,'').slice(0,EMPLOYEE_CODE_LENGTH);

/** Canonical persisted employee codes are always exactly six ASCII digits. */
export const isValidEmployeeCode=(value:string)=>/^\d{6}$/.test(value)&&value!=='000000';

/** Converts a historical five-digit input into its canonical six-digit value. */
export const normalizeEmployeeCode=(value:string):string|null=>{
  const trimmed=value.trim();
  if(isValidEmployeeCode(trimmed))return trimmed;
  if(/^\d{5}$/.test(trimmed)){
    const normalized=`0${trimmed}`;
    return isValidEmployeeCode(normalized)?normalized:null;
  }
  return null;
};

export const isAcceptedEmployeeCodeInput=(value:string)=>normalizeEmployeeCode(value)!==null;
