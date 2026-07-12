import type{NavigationItem}from'../../app/navigation';
export interface PermissionReader{has(permission:string):boolean}
export function createPermissionReader(codes?:Iterable<string>):PermissionReader{const allowed=new Set(codes??[]);return{has:p=>allowed.has(p)}}
export function visibleNavigationItems(items:NavigationItem[],reader:PermissionReader){return items.filter(item=>reader.has(item.permission))}
