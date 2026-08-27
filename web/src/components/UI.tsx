import type { ReactNode } from 'react';
export function PageHeader({eyebrow,title,description,action}:{eyebrow:string;title:string;description:string;action?:ReactNode}){return <header className="page-header"><div><span className="eyebrow">{eyebrow}</span><h1>{title}</h1><p>{description}</p></div>{action}</header>}
export function Badge({children,tone='blue'}:{children:ReactNode;tone?:'blue'|'green'|'amber'|'red'|'gray'}){return <span className={`badge ${tone}`}>{children}</span>}
export function Empty({text}:{text:string}){return <div className="empty">{text}</div>}
export function Toast({message}:{message:string}){return message?<div className="toast">✓ {message}</div>:null}
