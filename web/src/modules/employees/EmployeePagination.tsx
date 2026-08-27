export function EmployeePagination({
  page,
  totalPages,
  totalRows,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  totalRows: number;
  onPageChange: (page: number) => void;
}) {
  if (!totalRows) return null;
  return <nav className="employee-pagination" aria-label="Paginación de empleados">
    <span>Página {page} de {totalPages} · {totalRows} registros</span>
    <div className="button-row">
      <button type="button" className="secondary" disabled={page <= 1} onClick={() => onPageChange(page - 1)}>Anterior</button>
      <button type="button" className="secondary" disabled={page >= totalPages} onClick={() => onPageChange(page + 1)}>Siguiente</button>
    </div>
  </nav>;
}
