# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please do not open a public issue. Report it privately through
[GitHub security advisories](https://github.com/Muddyblack/nixdatifier/security/advisories/new).
Include the version, how to reproduce it, and what an attacker could do.

You can expect a first reply within a week.

## Scope

Nixdatifier runs privileged operations (switching or deleting generations, store
cleanup) through `pkexec`, and reads files such as `/run/secrets` metadata. Reports
about command injection, privilege escalation, unintended secret exposure, or
unsafe handling of flake and network data are in scope. The secrets tab shows
metadata only, never secret values.
