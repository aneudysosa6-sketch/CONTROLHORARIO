type BrandMarkProps = { className?: string; title?: string };

export function BrandMark({ className = '', title = 'OSINET' }: BrandMarkProps) {
  return <svg className={`brand-mark ${className}`.trim()} viewBox="0 0 64 64" role="img" aria-label={title}>
    <defs><linearGradient id="osinet-brand-gradient" x1="12" y1="8" x2="54" y2="58" gradientUnits="userSpaceOnUse"><stop stopColor="#57C8FF"/><stop offset=".58" stopColor="#1689FF"/><stop offset="1" stopColor="#0755DA"/></linearGradient></defs>
    <rect width="64" height="64" rx="18" fill="#07182C"/>
    <path d="M32 9.5A22.5 22.5 0 1 0 54.5 32 22.53 22.53 0 0 0 32 9.5Zm0 9A13.5 13.5 0 1 1 18.5 32 13.52 13.52 0 0 1 32 18.5Z" fill="url(#osinet-brand-gradient)"/>
    <path d="M32 20.5A11.5 11.5 0 0 0 20.5 32h7.2a4.3 4.3 0 0 1 8.6 0h7.2A11.5 11.5 0 0 0 32 20.5Z" fill="#2DD4A3"/>
    <circle cx="32" cy="32" r="4.4" fill="#F5FBFF"/>
  </svg>;
}
