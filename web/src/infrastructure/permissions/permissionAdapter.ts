import type{NavigationItem}from'../../app/navigation';
export interface PermissionReader{has(permission:string):boolean}
export const canonicalRole=(value?:string)=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toUpperCase();
export const isAdministratorRole=(code?:string,name?:string)=>['ADMIN','ADMINISTRADOR','ADMINISTRATOR'].includes(canonicalRole(code))||['ADMIN','ADMINISTRADOR','ADMINISTRATOR'].includes(canonicalRole(name));
export function createPermissionReader(codes?:Iterable<string>):PermissionReader{const allowed=new Set(codes??[]);return{has:p=>allowed.has(p)}}
export function visibleNavigationItems(items:NavigationItem[],reader:PermissionReader){return items.filter(item=>reader.has(item.permission))}
