# Todo List for Easter Egg Hunt Graph Generator

Based on the specs and current progress in main.R, here's a hierarchical checklist for completing the Easter egg hunt graph generator:

## Data Processing and Validation
- [x] **Modify input columns**: Add a `node_id` column (unique string based on hiding spot, e.g., sanitized version of hiding_spot) and an `outgoing_nodes` column (colon-delimited node_ids, can be empty for no pre-defined edges).
- [x] **Implement input validation**: Create function to check required columns and types (now including node_id and outgoing_nodes).
- [x] **Process subclusters**: Split subclusters by ':' and assign DEFAULT where needed.
- [x] **Determine eligible targets**: For each node, find connectable nodes based on subcluster overlap.

## Graph Construction
- [x] **Implement graph construction logic**: Create a function to randomly connect nodes respecting max incoming/outgoing edges, min incoming edges, and eligible targets.
- [x] **Handle edge constraints and randomization**: Ensure connections respect constraints; implement retry logic for failed connections; validate final graph.
- [x] **Honor pre-defined outgoing nodes**: 
  - Parse outgoing_nodes column to get pre-defined edges (as node_id strings).
  - Treat pre-defined edges as already assigned (count toward max_outgoing_edges), but allow them to override constraints (e.g., ignore subcluster eligibility or max edges for pre-defined).
  - For nodes with blank outgoing_nodes, fill randomly as before.
  - Add additional random outgoing edges only if max_outgoing_edges permits after pre-defined.

## Output Generation
- [x] **Update output dataframe**: Ensure output has all input columns (strict superset) plus any additional (e.g., outgoing_clues). Populate outgoing_nodes with colon-delimited node_ids of all assigned outgoing connections (no blanks).
- [x] **Generate Graphviz DOT file**: Write function to output graph as DOT file with nodes and directed edges.
- [x] **Generate SVG visualization**: Use system call to Graphviz to convert DOT to SVG.
- [x] **Create output data frame**: Build data frame with hiding spots and concatenated outgoing clues.
- [x] **Export spreadsheet**: Use rio::export to save data frame as CSV.

## Integration and Execution
- [x] **Add main execution flow**: Integrate all steps into cohesive script with error handling.
- [x] **Add command-line or configurable input**: Allow data_path, output_dir, seed via arguments.

## Testing and Quality
- [x] **Test with example data**: Run script on provided example to verify outputs and constraints.
- [x] **Persist output artifacts**: Write DOT file, render SVG, export clue graph as spreadsheet.
- [x] **Code review and cleanup**: Ensure adherence to coding style; remove unused code; optimize readability.
