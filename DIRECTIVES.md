# system-monitor-remote — Directives

Host agent that publishes System Monitor–compatible sensors for HA System Monitor Remote.

## Ownership
- **Masta-Rob** owns this home project DIRECTIVES.md. Flag Rob only for policy changes.

## Safety (always wins)
- No secrets in git. Bind/publish only on intended interfaces (prefer ZeroTier for server-to-server).

## Directives (priority order, highest first)
- Stay compatible with ha-system-monitor-remote.
- Prefer ZeroTier for host-to-HA traffic when both are estate boxes.

## Non-goals
- Not estate-shell; not a remote root shell.

## Standing rules that apply here
- No secrets in git. Nothing deployed without Rob's OK.

## Change log
- 2026-11-04 — Masta-Rob — Initial DIRECTIVES.md (Rob's OK: yes, pt1410u).
