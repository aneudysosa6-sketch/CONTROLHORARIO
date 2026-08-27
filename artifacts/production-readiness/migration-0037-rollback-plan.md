# Migration 0037 rollback plan

## Failure during migration

Any preflight, revoke, grant, or final validation error rolls back the complete
transaction. Do not add `CASCADE`, alter role memberships, or change ownership
to force completion.

## Regression after commit

Stop promotion and diagnose the exact caller that requires function execution.
Do not restore `PUBLIC` or `anon` access and do not edit an applied 0037 file.
Use a separately reviewed forward migration only if a new grantee is proven to
be required. Preserve direct `authenticated` execution and repeat the catalog
postflight plus functional smoke tests.

## Recovery target

The safe target remains:

- direct, non-grantable `EXECUTE` for `authenticated`;
- no effective or direct `EXECUTE` for `anon`;
- no `EXECUTE` for `PUBLIC`.

No data rollback is required because 0037 does not touch data. Production stays
NO-GO until the recovered ACL and dependent flows are validated.
