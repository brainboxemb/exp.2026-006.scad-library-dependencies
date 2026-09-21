# DEP-06 — full closure status and safe update

## User-facing contract

DEP-06 keeps the normal repository interface small:

```text
bootstrap.sh / bootstrap.ps1
update-repo.sh / update-repo.ps1
update-repo.sh status / update-repo.ps1 status
```

The status form combines released direct-dependency status with nested
owner/path/ref state.

## Qualified behaviour

- clean direct and nested state is visible;
- a dirty nested dependency is reported and blocks update;
- changing the project-owned util ref changes only that owner path;
- the mechint-owned nested util remains at its own ref;
- an uninitialized nested util is reported and normal update restores it;
- unrelated local paths are not deleted by closure traversal;
- the repository returns to a clean state.

Dependency removal remains an explicit owner/source change rather than guessed
recursive cleanup.

## Status

**Qualified.** Exact source
`b2b0a917e64234eee4092430219da1fb7acdd4f9`; DEP-06 run
`35644234755` is green on Linux and Windows, with all earlier dependency
regressions and normal SCAD production green on the same source. The qualified
change was merged as
`d9d09c08f2368482842e50419269e3079150d33a`.
