# OneBusAway Israel — Branch Integration Manifest

**Source of Truth Base:** `feature/israel-local-catalog-smart-map-provider-architecture`  
**Setup & Coordination Branch:** `agent/team-orchestration-20261018` (PR #2)

## Active Work Branches (Targeted for Propagation)
- `feature/israel-local-catalog-smart-map-provider-architecture` (Current development base)
- `agent/team-orchestration-20261018` (Draft setup PR)
- `feature/israel-mot-adapter`
- `fix/israel-runtime-region-search-weather`

## Default Branch
- `main` — Receives additive team documentation only without merging feature code.

## Audited Exceptions
- `feature/watchos` (Upstream feature branch)
- `upstream/*` tracking refs

## Future Branch Inheritance
All future branches created from `feature/israel-local-catalog-smart-map-provider-architecture` or `main` automatically inherit this configuration. Older branches can be checked with `tools/ai-team/ensure-team.ps1 -Check`.
