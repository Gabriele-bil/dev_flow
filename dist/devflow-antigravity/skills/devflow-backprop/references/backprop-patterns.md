# Backprop Gap Patterns

Taxonomy and gap families for `devflow.backprop` Step 3. Adapted from Forge's backprop-patterns reference.

## Gap taxonomy

| Class | Signal | Spec action |
| --- | --- | --- |
| **missing criterion** | Subtask exists; behavior it implies was never stated as an AC | Add AC under the subtask |
| **incomplete criterion** | AC exists; failure occurred inside its blind spot (boundary, error path, empty state) | Rewrite AC with the boundary explicit |
| **missing requirement** | No subtask relates to the behavior at all | Add subtask + AC; large scope → `devflow.task` |

Decision order: check existing ACs first, then subtasks, then declare missing requirement. Most escaped bugs are **incomplete criteria** — resist jumping to "missing requirement".

## Gap families

Tag every backprop with one family. Family drives the instinct domain (`backprop-[family]`) and the 3+ systemic rule.

| Family | Typical escaped bug | Standard clarify question it suggests |
| --- | --- | --- |
| **input-validation** | Empty string, null, overlong input, wrong format accepted | "For each user input: what is rejected, and what does the user see on rejection?" |
| **error-handling** | Network/IO failure leaves UI stuck or state corrupt | "For each external call: what happens on failure — retry, message, fallback?" |
| **concurrency** | Double-tap double-submits; race between fetch and navigation | "Which actions can fire twice or overlap, and what must happen when they do?" |
| **integration** | Contract mismatch with API/DB — nullable field, enum value, pagination | "Which external contracts does this touch, and are their edge values (null, empty page, unknown enum) specified?" |
| **state-lifecycle** | Stale cache after edit; state survives logout; init order | "For each stateful entity: when is it created, invalidated, and destroyed?" |
| **auth** | Action reachable without permission; role boundary unstated | "Which roles may perform each action, and what does the blocked path look like?" |

Failure fits no family → tag `other` with a 2-3 word label; recurring `other` labels become new families (propose adding a row here).

## Systemic rule (3+)

3+ instincts sharing a `backprop-[family]` domain in `.devflow-instincts.yaml` → the gap is systemic to this project, not incidental:

1. Propose the family's standard question (table above, adapted to project vocabulary) as a standing `devflow.clarify` question.
2. On user acceptance: log as instinct — `domain: clarify`, `trigger: "clarifying any task.md"`, `action: "ask: [question]"`, confidence 0.9. The `session-start-learnings` hook injects it; clarify's 8D scan picks it up.

## Worked example

Bug: submit button double-tap creates two records.

- Trace: `order_submit_service.dart` → Traceability → subtask "user submits order" → AC "order saved on submit".
- Class: **incomplete criterion** (AC silent on repeated submission). Family: **concurrency**.
- Tightened AC: "submit disabled while request in flight; repeated taps create exactly one order".
- Regression: `order_submit_test.dart :: 'double tap creates single order'` — fails before fix.
- Instinct: `domain: backprop-concurrency`, trigger "actions with async submit", action "AC must state in-flight behavior".
