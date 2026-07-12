import{createClient,type SupabaseClient}from'@supabase/supabase-js';
let client:SupabaseClient|undefined;
export function getSupabaseClient(){const url=import.meta.env.VITE_SUPABASE_URL?.trim();const key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();if(!url||!key)throw new Error('Faltan VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY.');client??=createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,storage:localStorage}});return client}
