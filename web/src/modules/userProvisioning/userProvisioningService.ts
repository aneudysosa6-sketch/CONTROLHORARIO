import{getSupabaseClient}from'../../infrastructure/supabase/client';
export interface PendingAuthUser{id:string;email:string;full_name:string;created_at:string}
export interface CatalogItem{id:string;name:string;code?:string;company_id?:string}
export interface AvailableEmployee{id:string;nombre_completo:string;codigo_empleado:string;empresa_id:string}
export interface ProvisioningState{users:PendingAuthUser[];companies:CatalogItem[];roles:CatalogItem[];employees:AvailableEmployee[]}
export interface ProvisionInput{user_id?:string;email?:string;full_name:string;company_id:string;role_id:string;employee_id?:string;status:'active'|'invited'}
async function invoke<T>(body:Record<string,unknown>):Promise<T>{const{data,error}=await getSupabaseClient().functions.invoke('user-provisioning',{body});if(error)throw error;if(data?.error)throw new Error(data.error);return data as T}
export const userProvisioningService={list:(company_id?:string)=>invoke<ProvisioningState>({action:'list',company_id}),provision:(input:ProvisionInput)=>invoke<{profile:unknown}>({action:'provision',...input}),invite:(input:ProvisionInput)=>invoke<{profile:unknown}>({action:'invite',...input})};
