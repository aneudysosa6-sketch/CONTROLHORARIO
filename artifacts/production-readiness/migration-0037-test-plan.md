# Migration 0037 test plan

## Static gates

1. Confirm a single active migration for every number `0001` through `0037`.
2. Confirm 0037 contains one transaction and changes only the ACL of
   `public.tiene_permiso(text)`.
3. Confirm no data, RLS, policy, ownership, membership, schema, table, default
   privilege, or `service_role` statement is present.
4. Run `git diff --check`.
5. Confirm the production precheck remains one SELECT-only statement returning
   76 checks plus `FINAL_DECISION` with six columns.

## PostgreSQL 17 local tests

Use only an isolated local database with synthetic objects and no published
ports. Do not use a linked Supabase project.

1. Create the versioned function signature and the `authenticated`/`anon`
   roles in a disposable database.
2. Seed drift: grant function execution to `PUBLIC` and `anon`, and remove the
   direct `authenticated` grant.
3. Apply 0037 and run `migration-0037-postflight.sql`; require
   `acl_matches_expected=true`.
4. Apply 0037 a second time; require the same PASS result.
5. Confirm a missing function or role aborts the transaction.
6. Confirm inherited effective execution for `anon` is not silently repaired:
   the final guard must abort and roll back.

## Promotion gates

Before production, rerun the production precheck and require no unresolved
BLOCKED result. Apply migrations in numeric order, then run the 0037 postflight
and the approved functional smoke tests with synthetic data. This task performs
none of those remote operations.
