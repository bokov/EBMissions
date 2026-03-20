
* Prefer one short pipeline over several temporary variables.
* Prefer vectorized mutate() / across() / sapply() / lapply() / mapply() / map_*() over explicit loops when possible.
* Prefer inline expressions over extracting a helper if the logic is short and single-use.
* Try to keep code flat and avoid nested control flow unless there is a compelling reason (which should be documented in comments).
* Extract a function only if it is at least one of:
    * reused,
    * conceptually important,
    * or materially improves readability.
* If a short expression can replace a whole helper function cleanly, prefer the expression.
* Optimize for readable density, not maximum scaffolding.
