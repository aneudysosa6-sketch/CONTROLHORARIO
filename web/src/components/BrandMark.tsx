type BrandMarkProps = {
  className?: string;
  title?: string;
  size?: number;
};

type BrandCopyProps = {
  className?: string;
  tagline?: string;
  large?: boolean;
};

export function BrandMark({ className = '', title = 'Control Horario', size = 44 }: BrandMarkProps) {
  return <svg
    className={`brand-mark ${className}`.trim()}
    viewBox="0 0 96 96"
    role="img"
    aria-label={title}
    style={{ width: size, height: size, flex: 'none', borderRadius: 0, background: 'transparent', boxShadow: 'none', filter: 'drop-shadow(0 0 11px #1689ff55)' }}
  >
    <title>{title}</title>
    <defs>
      <linearGradient id="control-horario-blue" x1="14" y1="12" x2="82" y2="84" gradientUnits="userSpaceOnUse">
        <stop stopColor="#55D8FF"/>
        <stop offset=".54" stopColor="#1689FF"/>
        <stop offset="1" stopColor="#0755DA"/>
      </linearGradient>
      <radialGradient id="control-horario-surface" cx="0" cy="0" r="1" gradientTransform="translate(48 35) rotate(90) scale(62)" gradientUnits="userSpaceOnUse">
        <stop stopColor="#0D3157"/>
        <stop offset="1" stopColor="#051121"/>
      </radialGradient>
    </defs>
    <rect x="2" y="2" width="92" height="92" rx="24" fill="url(#control-horario-surface)" stroke="#1689FF" strokeOpacity=".34"/>
    <g fill="none" stroke="url(#control-horario-blue)" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 32V21a4 4 0 0 1 4-4h12M63 17h12a4 4 0 0 1 4 4v11M17 64v11a4 4 0 0 0 4 4h12M63 79h12a4 4 0 0 0 4-4V64" strokeWidth="4.5"/>
      <path d="M48 19c-12.6 0-19 8.6-18.4 22.5.6 14.2 7 25.5 18.4 30.4 11.4-4.9 17.8-16.2 18.4-30.4C67 27.6 60.6 19 48 19Z" strokeWidth="1.8" strokeOpacity=".9"/>
      <path d="M48 22v47M35.5 29 60 60M60.5 29 36 60M30 42h36M33 53h30M38 24l-3 18 7 21M58 24l3 18-7 21M35 29l13 13 13-13M35 53l13-11 13 11M42 63l6-10 6 10" strokeWidth="1" strokeOpacity=".62"/>
    </g>
    <g fill="#63DCFF">
      <circle cx="48" cy="22" r="1.8"/><circle cx="35.5" cy="29" r="1.7"/><circle cx="60.5" cy="29" r="1.7"/>
      <circle cx="30" cy="42" r="1.6"/><circle cx="48" cy="42" r="2"/><circle cx="66" cy="42" r="1.6"/>
      <circle cx="35" cy="53" r="1.7"/><circle cx="48" cy="53" r="1.7"/><circle cx="61" cy="53" r="1.7"/>
      <circle cx="42" cy="63" r="1.6"/><circle cx="54" cy="63" r="1.6"/><circle cx="48" cy="70" r="1.8"/>
    </g>
    <circle cx="69" cy="69" r="18.5" fill="#071426" stroke="#05101E" strokeWidth="5"/>
    <circle cx="69" cy="69" r="17" fill="#071426" stroke="url(#control-horario-blue)" strokeWidth="3.6"/>
    <path d="M69 55v4M69 69V60M69 69l7 4" fill="none" stroke="#F4FAFF" strokeWidth="3.2" strokeLinecap="round"/>
    <path d="M69 53.5v3.5" stroke="#7CE746" strokeWidth="3" strokeLinecap="round"/>
    <circle cx="69" cy="69" r="2.2" fill="#F4FAFF"/>
  </svg>;
}

export function BrandCopy({ className = '', tagline = 'FACE TIME ERP ENTERPRISE', large = false }: BrandCopyProps) {
  return <div className={className} style={{ minWidth: 0 }}>
    <b style={{ display: 'flex', gap: large ? 6 : 4, alignItems: 'baseline', margin: 0, fontSize: large ? 17 : 12, lineHeight: 1.05, letterSpacing: large ? '.075em' : '.045em', whiteSpace: 'nowrap' }}>
      <span>CONTROL</span><span style={{ color: '#279CFF' }}>HORARIO</span>
    </b>
    <small style={{ display: 'block', marginTop: 4, color: '#8495AE', fontSize: large ? 8.5 : 7, lineHeight: 1, letterSpacing: '.075em', whiteSpace: 'nowrap' }}>{tagline}</small>
  </div>;
}
