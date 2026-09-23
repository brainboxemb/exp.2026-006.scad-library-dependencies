# Repository agent guidance

Start with [README.md](README.md) and the retained cross-project Experiment 006
record in `brainboxemb.meta/experiments/006-transitive-scad-library-dependencies`.

For current BrainboxEmb working conventions, read
[brainboxemb.meta/AGENTS.md](https://github.com/brainboxemb/brainboxemb.meta/blob/main/AGENTS.md).

This repository is completed experiment/regression evidence, not a production
owner. Therefore:

- preserve the exact dependency pins, testcases and evidence needed to reproduce
  the qualified experiment;
- treat those exact versions as historical experiment baselines, not current
  portfolio defaults;
- do not add `lib.scad.util` directly to the consumer fixture merely to make
  the retained transitive-dependency question pass;
- keep production changes in their owning tool/library repositories;
- do not weaken a retained testcase to make a regression run green;
- modify the retained lab only when an explicit new experiment/migration asks it
  to requalify the same acceptance boundary.

This completed experiment intentionally does not duplicate the normal
owner-repository numbered documentation set. Generic commit/PR/CI discipline is
owned by the current meta guidance rather than copied here.
