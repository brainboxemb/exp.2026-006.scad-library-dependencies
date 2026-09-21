# DEP-02 — controlled transitive external closure

## Question

Can the dependency tree be traversed transitively without falling back to
unrestricted recursive Git submodules?

## Prototype rule

The experiment-owned prototype reads each repository's existing `project.yml`
and follows only dependencies with:

```text
role: external
type: git-submodule
```

The root's released bootstrap remains unchanged. DEP-02 runs after that direct
bootstrap and extends only the external-library closure.

With the current fixture the transition is:

```text
before
  mechint/ext/lib.scad.util        uninitialized
  mechint/tools/tool.git-project   uninitialized
  mechint/tools/tool.scad-project  uninitialized

after controlled closure
  mechint/ext/lib.scad.util        initialized at its owner pin
  mechint/tools/tool.git-project   still uninitialized
  mechint/tools/tool.scad-project  still uninitialized

and inside util
  util/tools/tool.git-project      still uninitialized
  util/tools/tool.scad-project     still uninitialized
```

## Owner authority

For every followed dependency the prototype requires:

- a committed gitlink in the owning repository;
- a matching `.gitmodules` URL;
- a configured ref in the owner's `project.yml`;
- a clean initialized dependency before revision alignment.

The semantic ref is resolved and compared with the checked-out revision. The
prototype may align the worktree to that ref, but it does not stage or commit
the owner's gitlink.

## Recursion and cycles

Traversal is recursive through newly initialized external dependencies.

Cycle detection is ancestry-based: encountering the same repository URL again
on the current dependency chain is an error. The visited set is deliberately
not global, because DEP-05 must later allow the same foundation repository at
two independent sibling paths with different owner pins.

## Qualification

`dep-02-closure.yml` runs the same rule through Bash on Ubuntu and PowerShell on
Windows. It first replays DEP-01, then applies the external closure, then
asserts that only the intended nested library worktree became initialized.

Qualified evidence:

- exact source: `2a01614301aa38c298389f8f961ad4708111b93b`;
- DEP-01 regression run `35627708195` — Linux and Windows green;
- DEP-02 run `35627708512` — Linux and Windows green;
- SCAD production run `35627709234` — green;
- merged DEP-02 baseline: `5385f797ea549c39f075da11e3fa838350e5e44c`.
