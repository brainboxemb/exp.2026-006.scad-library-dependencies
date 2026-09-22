# Generated build output

This directory contains generated output for a successful project build.
It is generated automatically and should not be edited manually.

## Artifacts

- [Design documentation](design/README.md)
- [PNG renders](png/README.md)
- [STL exports](stl/)

<!-- scad-project-evidence-navigation -->
## Producer execution evidence

These files describe the SCAD producer executions that actually created the retained output.
They remain unchanged when equivalent output is later hydrated from cache.

- [scad-build execution](evidence/executions/scad-build/execution.json) — capability, producer source revision, exact owner revision, result and producer timing when available.
  - [scad-build log](evidence/executions/scad-build/execution.log) — concise human-readable producer summary.
- [scad-docs execution](evidence/executions/scad-docs/execution.json) — capability, producer source revision, exact owner revision, result and producer timing when available.
  - [scad-docs log](evidence/executions/scad-docs/execution.log) — concise human-readable producer summary.

## Domain evidence

Structured SCAD/SCons reports contain the detailed target-level build and cache decisions.
They are richer domain evidence, not alternate producer logs.

- [dependency-provenance.json](evidence/domain/dependency-provenance.json)
- [last-build.json](evidence/domain/last-build.json)
- [last-design-build.json](evidence/domain/last-design-build.json)

## Orchestration/materialization evidence

Current-run orchestration evidence explains why capabilities were selected, whether Moon executed or hydrated them, and how long current materialization and snapshot preparation took.
Producer execution evidence above remains the authority for the work that originally created cached output.

- [Workflow phase timings](orchestration/timings.json)
- [Run context and snapshot-preparation timing](orchestration/run-context.json)
- [Moon impact decision](orchestration/impact-decision.json)
- [Affected Moon task ids](orchestration/affected-task-ids.json)
- [SCAD execution/materialization plan](orchestration/scad-ci-plan.json)

### Current workflow timing

| Phase | Duration |
| --- | ---: |
| Preflight + execution plan | 11.456 s |
| Cache restore | 450 ms |
| Runtime pull | 12.633 s |
| Capability materialization | 7.140 s |
| Cache save | 922 ms |
| Validation + finishing | 483 ms |
| Snapshot preparation | 3 ms |
| **Total to prepared snapshot** | **33.163 s** |

The table stops when this generated snapshot is ready. The remote branch push happens afterwards; detailed per-capability timings remain in the materialization files below.

- [consumer:scad.build materialization](orchestration/moon-invocations/consumer_scad.build/materialization.json) — current execute/cache/hydrate result and duration.
  - [consumer:scad.build raw Moon/producer log](orchestration/moon-invocations/consumer_scad.build/moon.log)
- [consumer:scad.docs materialization](orchestration/moon-invocations/consumer_scad.docs/materialization.json) — current execute/cache/hydrate result and duration.
  - [consumer:scad.docs raw Moon/producer log](orchestration/moon-invocations/consumer_scad.docs/moon.log)

## Publication context

`publication-info.txt` records generated-branch context plus source, tooling and runtime provenance.
Publication/finalization consumes prepared output and must not rewrite producer execution evidence.
