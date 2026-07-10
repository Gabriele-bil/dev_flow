# Skill Evals

How this repo checks that core pipeline skills **trigger** correctly and
**stay distinct** from each other, on top of the structural checks in
`scripts/validate-skills.sh`.

## Tiers

| Tier | What it checks | Runs | Cost |
| --- | --- | --- | --- |
| 1. Structural | Frontmatter, required sections, style | `bash scripts/validate-skills.sh [--strict]` | Free |
| 2. Trigger & routing | Positive prompts rank their skill in top-k; negative prompts rank the correct owner skill above the skill under test; no two descriptions collide | `bash scripts/run-evals.sh` | Free |
| 3. Behavioral | An agent following the skill actually does what it promises | Not implemented yet | Tokens |

Tier 2 is a **lexical approximation**: it scores prompts against skill
descriptions by keyword overlap (bag-of-words, stopwords removed), not
semantic understanding. It catches the two failure modes that dominate real
routing bugs:

- a description missing the vocabulary a user would actually say (positive
  prompt fails to rank), and
- an over-broad or near-duplicate description that collides with another
  skill (collision check, or a negative prompt outranking the true owner).

A Tier-2 failure usually means "fix the description," not "fix the eval."

## Running

```bash
bash templates/devflow/scripts/run-evals.sh
```

Requires `jq`. Deterministic — no LLM calls, safe to run in CI.

## Eval case format

One file per core skill: `evals/cases/<skill-name>.json`.

```json
{
  "skill_name": "devflow-task",
  "trigger": {
    "positive": [
      { "prompt": "I have an idea for a new feature, help me turn it into a proper task spec", "top_k": 3 }
    ],
    "negative": [
      { "prompt": "Check consistency between task, plan and constitution before implementing", "owner": "devflow-analyze" }
    ]
  }
}
```

- `positive[]`: realistic user prompts that should route to this skill.
  `top_k` (default 3) is how far down the ranked list is still acceptable.
- `negative[]`: prompts that belong to a different skill (`owner`). The
  runner asserts the owner outranks the skill under test — a real pairwise
  routing check, not one that passes vacuously when the prompt matches
  nothing.

**Writing good trigger prompts:** paraphrase how a user would actually ask;
don't copy words straight out of the skill's `description:` — that gates the
eval instead of testing it.

## Adding a skill

New core skill under `skills/devflow-<name>/` → add
`evals/cases/devflow-<name>.json` with at least 3 positive and 2 negative
prompts, and add prompts belonging to it as `owner` in whichever sibling
skills it's most likely to be confused with.

## Metrics

`run-evals.sh` prints a **top-k pass rate** for positive prompts. It isn't
gated on a specific threshold yet — watch it over time; a falling rate means
descriptions are drifting toward each other or losing real-world vocabulary.
The collision check errors at >=75% pairwise description similarity and
warns at >=50%.

## Scope

This intentionally covers core pipeline skills only (`skills/`), not
adapter skills (`adapters/*/skills/`) — adapter skills are scoped by file
path triggers documented in each `ADAPTER.md`, not by natural-language
routing, so lexical trigger evals don't apply the same way.

**`disable-model-invocation: true` skills are excluded from trigger checks.**
About half of devflow's core skills (`devflow-ship`, `devflow-implement`,
`devflow-status`, etc.) set this flag — they're reachable only via an
explicit slash command (`/devflow.ship`), never by the model matching a
natural-language prompt against the description. Running a trigger-routing
eval against them tests a mechanism that doesn't exist for that skill, so
`run-evals.sh` prints `SKIP` for:

- a case whose own `skill_name` is not NL-invocable (its positive/negative
  prompts are skipped entirely), and
- an individual negative prompt whose `owner` is not NL-invocable (the
  "owner should outrank" comparison is meaningless if the owner can't be
  auto-selected in the first place).

The description collision check still runs across every skill regardless of
this flag — a confusing near-duplicate description is still a discovery/
readability problem even for a command-only skill.
