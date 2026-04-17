# Quick stress-test (before finalizing a DevFlow task)

Use this **after** you understand `docs/product.md` and **before** you lock Summary, scope boundaries, and subtasks. Pick the dimensions that matter; skip what does not apply.

## Dimensions

1. **User value** — Who benefits, and is this a sharp pain or a nice-to-have? Would the target user change behavior?
2. **Feasibility in Petmate** — Fits the stack and patterns in `constitution.md` / `registry.md`? Any dependency or policy risk (auth, RLS, locales, responsive shell)?
3. **Overlap** — Does this duplicate or collide with a feature marked **implemented** in `docs/product.md`? If it extends an existing feature, say so explicitly in Notes.
4. **Scope honesty** — Is the “minimum useful” slice obvious? If not, narrow **In scope** and grow **Out of scope** until it is.
5. **Riskiest assumption** — What single belief, if false, makes the task pointless? Put it in **Key assumptions** (and how to validate if non-obvious).

## Tone

If the idea is weak, vague, or too large for one task, say so briefly and tighten scope or send the user to brainstorming first. Prefer a useful small task over a heroic vague one.
