import { createContext, useContext, useState, type ReactNode } from 'react';
import { authService } from '../services/storage';
import type { Session } from '../types';
type AuthValue={session:Session|null;login:(u:string,p:string)=>Promise<void>;logout:()=>void};
const AuthContext=createContext<AuthValue|null>(null);
export function AuthProvider({children}:{children:ReactNode}){const [session,setSession]=useState(authService.getSession());return <AuthContext.Provider value={{session,login:async(u,p)=>setSession(await authService.login(u,p)),logout:()=>{authService.logout();setSession(null)}}}>{children}</AuthContext.Provider>}
export function useAuth(){const value=useContext(AuthContext);if(!value)throw new Error('AuthProvider requerido');return value}
