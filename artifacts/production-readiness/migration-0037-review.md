# Migration 0037 review

## Scope

`0037_tiene_permiso_execute_acl.sql` normalizes only the function ACL of
`public.tiene_permiso(text)`. It does not replace the function body or change
data, RLS, policies, table privileges, `service_role`, ownership, memberships,
default privileges, schema privileges, or any other function.

## Final contract

| Grantee | Effective EXECUTE | Direct EXECUTE | Grant option |
|---|---:|---:|---:|
| `authenticated` | true | true | false |
| `anon` | false | false | false |
| `PUBLIC` | false | false | false |

The migration revokes existing ACL entries for these three grantees and grants
only direct `EXECUTE` to `authenticated`. `RESTRICT` is intentional: dependent
grants stop the transaction instead of being removed transitively.

## Safety properties

- `BEGIN`/`COMMIT` make the change atomic.
- Repeating the revoke/grant sequence produces the same ACL.
- Preflight guards require the exact function and both Supabase roles.
- The final guard checks effective access, direct ACL, and grant option state.
- Inherited, ownership, or membership drift that preserves access for `anon`
  causes rollback; 0037 does not broaden its scope to repair those routes.

## Precheck alignment

The production precheck reports the current ACL mismatch as
`REMEDIATED_BY_0037` while this migration is pending. It continues to block
missing objects, other RPC ACL drift, or a mismatch remaining after 0037.
The catalog contract for `obtener_departamentos_supervisor_actual()` expects
`uuid` with `proretset=true`, matching the versioned `RETURNS TABLE` definition.

## Deployment state

Local PostgreSQL 17 validation passed for the first application, a second
idempotent application, the SELECT-only postflight, and fail-closed rollback
when `anon` retained execution through an inherited role. The precheck returned
76 unique checks plus `FINAL_DECISION`, with six columns.

Migration 0037 remains pending for production; production remains NO-GO until
the full precheck, migration sequence, postflight, smoke tests, and operational
approvals complete.
