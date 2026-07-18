import type{NavigationItem}from'../../app/navigation';
export interface PermissionReader{has(permission:string):boolean}
export const canonicalRole=(value?:string)=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toUpperCase();
export const isAdministratorRole=(code?:string,name?:string)=>['ADMIN','ADMINISTRADOR','ADMINISTRATOR'].includes(canonicalRole(code))||['ADMIN','ADMINISTRADOR','ADMINISTRATOR'].includes(canonicalRole(name));
const canonicalPermission=(value:string)=>value.trim().toLowerCase();
const permissionAliases=(permission:string)=>{
 const normalized=canonicalPermission(permission);
 if(normalized.endsWith('.view'))return[normalized,normalized.slice(0,-5)+'.ver'];
 if(normalized.endsWith('.ver'))return[normalized,normalized.slice(0,-4)+'.view'];
 return[normalized];
};
export function createPermissionReader(codes?:Iterable<string>):PermissionReader{
 const allowed=new Set(Array.from(codes??[],canonicalPermission));
 return{has:permission=>permissionAliases(permission).some(code=>allowed.has(code))}
}
export function visibleNavigationItems(items:NavigationItem[],reader:PermissionReader,isAdministrator=false){
 return items.filter(item=>isAdministrator||(Array.isArray(item.permission)?item.permission.some(permission=>reader.has(permission)):reader.has(item.permission)))
}
