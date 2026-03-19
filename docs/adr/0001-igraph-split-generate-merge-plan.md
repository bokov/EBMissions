# ADR 0001: Future igraph-based split-generate-merge graph generation plan

- Status: Proposed
- Date: 2026-03-19
- Deciders: Repository maintainers
- Scope: Future design direction only; not yet in implementation scope

## Context

The current graph generation pipeline contains custom logic for subcluster eligibility, randomized edge assignment, and repair steps. A future iteration of this project is expected to change the problem definition in the following ways:

1. The input will be split by subcluster membership, duplicating rows for nodes that belong to multiple subclusters.
2. Each per-subcluster graph must be rooted, directed, and oriented.
3. Degree targets will become expected in/out edges instead of maximum in/out edges.
4. User-specified edges must still be respected, overriding expected edges and subcluster rules, but they must not override rootedness.
5. If one or more nodes have `clues_to_this_spot == "START"`, one of them becomes the root of the merged graph and the remaining `START` nodes are rewritten to `FALSE_START`; otherwise a synthetic root is added.

This ADR records the recommended future design for using `igraph` to shorten custom code as much as possible under those assumptions. It is intentionally a plan for later work and does not change the currently implemented behavior.

## Decision

Adopt a future split -> generate -> merge architecture that uses `igraph` as the primary graph engine for random graph construction and validation, while retaining a smaller amount of custom orchestration code for root selection, user-edge enforcement, duplicate-node merging, and warnings.

## Recommendations

### 1. Remove future dependence on pairwise eligibility expansion

Under the planned split-by-subcluster model, the current pairwise overlap computation should no longer be the primary mechanism for deciding admissible targets.

Recommendation:

- Duplicate each multi-subcluster node into one working-row per subcluster.
- Generate each subcluster graph independently.
- Merge graphs on duplicated node identities afterward.

Expected effect:

- The current `find_eligible_targets()`-style logic can become unnecessary in the future implementation.
- The admissibility problem becomes a data-preparation step instead of a graph-construction step.

### 2. Build each subcluster around an igraph rooted tree backbone

Each subcluster graph must be rooted, directed, and oriented.

Recommendation:

- Choose the per-subcluster root before any random graph generation.
- Prefer a duplicated multi-subcluster node as the root when one is available.
- Otherwise add a synthetic root node whose other subcluster is `DEFAULT`.
- Generate a random rooted directed backbone with `igraph::sample_tree(directed = TRUE)`, which orients edges away from the root.
- Validate backbone rootedness with `igraph::is_tree(mode = "out", details = TRUE)`.

Expected effect:

- Rootedness and orientation are guaranteed at the backbone stage instead of being repaired later.
- A large portion of custom rooted-graph construction logic can be replaced by `sample_tree()` plus simple relabeling and validation.

### 3. Use expected-degree generators only for extra non-backbone edges

The planned model uses expected in/out edges rather than hard maxima.

Recommendation:

- Treat the rooted tree backbone as mandatory structure.
- Compute the residual expected in/out weights after accounting for backbone edges and user-specified edges.
- Use `igraph::sample_chung_lu()` to generate additional directed edges from those residual expected in/out weights.
- Use the Chung-Lu graph only as a proposal for extra edges, not as the entire graph, because the backbone and user-specified edges are mandatory.

Expected effect:

- Custom degree-balancing logic can be replaced by a smaller wrapper around `sample_chung_lu()`.
- The remaining custom logic is limited to residual-weight calculation and proposal filtering.

### 4. Preserve rootedness and orientation by restricting extra edges to a root-respecting order

A pure directed Chung-Lu draw does not by itself guarantee a rooted oriented graph.

Recommendation:

- Derive a root-respecting order from the tree backbone.
- Allow additional sampled edges only when they respect that order.
- Reject self-loops and duplicate directed edges.
- Detect and reject or prune mutual edges with `igraph::which_mutual()`.
- If acyclicity is later elevated from a preference to a requirement, use `igraph::is_dag()`, `igraph::topo_sort()`, and, if necessary, `igraph::feedback_arc_set()` during cleanup.

Expected effect:

- The graph remains rooted and oriented after extra edges are added.
- `igraph` handles detection and cleanup primitives while custom code keeps responsibility for the root-respecting policy.

### 5. Apply user-specified edges before stochastic completion

User-specified edges override expected edges and subcluster rules, but not rootedness.

Recommendation:

- Materialize all user-specified edges into the relevant per-subcluster graph before random completion.
- Validate each specified edge against rootedness and orientation requirements before accepting it.
- Emit warnings when a specified edge is incompatible with the selected root or with required orientation.
- Subtract accepted user edges from the residual expected in/out weights before calling `sample_chung_lu()`.

Expected effect:

- User intent is preserved wherever compatible with rootedness.
- Expected-degree generation becomes a fill-in step instead of a competing source of truth.

### 6. Merge subcluster graphs with named-vertex graph union

After per-subcluster generation, duplicated nodes must be collapsed back into a merged graph.

Recommendation:

- Assign stable canonical vertex names before graph construction.
- Build each subcluster graph as a named igraph object.
- Merge the per-subcluster graphs with `igraph::union(..., byname = TRUE)`.
- Use `igraph::simplify()` after union to remove duplicate directed edges while preserving or combining edge attributes deliberately.

Expected effect:

- Custom edge-list merge code can be shortened substantially.
- Merge behavior becomes more declarative and easier to validate.

### 7. Handle merged-graph rooting with a final root policy pass

The merged graph has special root semantics that differ from the per-subcluster roots.

Recommendation:

- If one or more nodes have `clues_to_this_spot == "START"`, choose one as the merged-graph root.
- Rewrite all other `START` values to `FALSE_START` before final output.
- Attempt to orient all edges incident from the chosen `START` root outward.
- If no `START` node exists, add a synthetic merged root node.
- Validate reachability from the final root with `igraph::subcomponent(mode = "out")`.

Expected effect:

- The future merged graph has a single canonical entry point.
- `igraph` helps validate the merged root's reachability without replacing the domain-specific root-selection policy.

### 8. Keep warnings and impossibility handling as custom orchestration

The future plan still includes requirements that are domain-specific rather than model-specific.

Recommendation:

Keep custom code for:

- warning when user-specified edges conflict with rootedness,
- warning when the split -> generate -> merge process causes realized degree counts to diverge from expected values,
- warning when a subcluster requires a synthetic root,
- warning when merge-time duplication forces unexpected edge inflation,
- warning when the requested structure is impossible under the chosen root policy.

Expected effect:

- `igraph` replaces graph mechanics, not application policy.
- The remaining custom code is smaller, clearer, and focused on repository-specific behavior.

## Consequences

### Positive

- The future codebase can eliminate most explicit pairwise target-eligibility logic.
- Rootedness can be guaranteed earlier by using tree backbones instead of repairing random graphs after the fact.
- Expected-degree generation becomes shorter and more standard by delegating the stochastic portion to `sample_chung_lu()`.
- Merging per-subcluster graphs can become simpler by relying on named-vertex `union()` and `simplify()`.
- Validation steps can use `igraph` primitives instead of ad hoc edge-list traversals.

### Negative

- `igraph` still does not encode the full domain policy; some orchestration code remains necessary.
- Expected-degree models will only approximate degree targets, especially after filtering and merging.
- Root-preserving cleanup after stochastic generation remains a custom design problem.
- User-specified edges can still force warning-heavy or partially degraded outputs.

## Explicitly out of scope for this ADR

This ADR does not authorize any of the following in the current scope:

- editing current executable code,
- changing the currently implemented graph-generation semantics,
- changing active contributor or repository policy documents,
- claiming that the present implementation already follows this design.

The purpose of this ADR is only to record a future plan for a later refactor.

## References

- igraph reference index: https://r.igraph.org/reference/
- `sample_tree()`: https://r.igraph.org/reference/sample_tree.html
- `is_tree()`: https://r.igraph.org/reference/is_tree.html
- `sample_chung_lu()`: https://r.igraph.org/reference/sample_chung_lu.html
- `which_mutual()`: https://r.igraph.org/reference/which_mutual.html
- `is_dag()`: https://r.igraph.org/reference/is_dag.html
- `topo_sort()`: https://r.igraph.org/reference/topo_sort.html
- `feedback_arc_set()`: https://r.igraph.org/reference/feedback_arc_set.html
- `union()`: https://r.igraph.org/reference/union.igraph.html
- `simplify()`: https://r.igraph.org/reference/simplify.html
- `subcomponent()`: https://r.igraph.org/reference/subcomponent.html
