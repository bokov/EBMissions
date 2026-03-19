# This function creates a base sample table. Input: row count. Output: tibble.
make_sample_rows <- function(nn_rows = 60L){
  tibble(
    hiding_spot = sprintf("Spot %03d", seq_len(nn_rows))
    ,clues_to_this_spot = sprintf("Clue %03d", seq_len(nn_rows))
    ,max_incoming_edges = rep(c(2L, 3L, 1L, 4L, 2L), length.out = nn_rows)
    ,max_outgoing_edges = rep(c(2L, 1L, 3L, 2L, 2L), length.out = nn_rows)
    ,subclusters = rep(c(NA, "indoors", "yard", "indoors:yard", "DEFAULT:indoors", "DEFAULT:yard"), length.out = nn_rows)
    ,node_id = sprintf("spot_%03d", seq_len(nn_rows))
    ,outgoing_nodes = NA_character_
  );
}

# This function creates the worst-case fixture. Input: row count. Output: tibble.
make_worst_case_input <- function(nn_rows = 60L){
  tibble(not_a_required_column = seq_len(nn_rows));
}

# This function creates a realistic partial input. Input: row count. Output: tibble.
make_realistic_partial_input <- function(nn_rows = 60L){
  base_tbl <- make_sample_rows(nn_rows);

  base_tbl <- base_tbl %>%
    mutate(
      max_incoming_edges = replace(max_incoming_edges, c(2L, 11L), c(NA_integer_, -5L))
      ,max_outgoing_edges = replace(max_outgoing_edges, c(3L, 15L), c(NA_integer_, -2L))
      ,subclusters = replace(subclusters, c(1L, 8L, 19L), c(NA_character_, "yard", "DEFAULT:yard"))
      ,clues_to_this_spot = replace(clues_to_this_spot, c(4L, 22L), c(NA_character_, ""))
      ,hiding_spot = replace(hiding_spot, c(7L), c(NA_character_))
      ,max_incoming_edges = replace(max_incoming_edges, c(5L), c(0L))
    ) %>%
    select(
      hiding_spot
      ,clues_to_this_spot
      ,max_incoming_edges
      ,max_outgoing_edges
      ,subclusters
      ,extra_notes = node_id
      ,priority_hint = outgoing_nodes
    );

  base_tbl;
}

# This function creates an ideal input table. Input: row count. Output: tibble.
make_ideal_input <- function(nn_rows = 60L){
  make_sample_rows(nn_rows) %>%
    mutate(
      outgoing_nodes = NA_character_
      ,subclusters = replace(subclusters, c(1L, 13L, 27L), c(NA_character_, NA_character_, "DEFAULT:indoors"))
    );
}
