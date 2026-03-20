make_graph_fixture <- function() {
  tibble(
    hiding_spot = c("Alpha", "Beta", "Gamma", "Delta"),
    clues_to_this_spot = c("START", "START", "Clue G", "Clue D"),
    max_incoming_edges = c(0L, 1L, 1L, 1L),
    max_outgoing_edges = c(1L, 2L, 1L, 1L),
    subclusters = c("A", "A", "A:B", "B"),
    node_id = c("alpha", "beta", "gamma", "delta"),
    outgoing_nodes = c("", "gamma", "", "")
  )
}

normalize_graph_fixture <- function(tbl = make_graph_fixture()) {
  tbl %>%
    fn_force_valid_input() %>%
    mutate(subcluster_vec = lapply(subclusters, function(xx) unique(strsplit(xx, ":")[[1]]))) %>%
    find_eligible_targets()
}

test_that("fn_enforce_one_xcol creates or keeps exactly one START row", {
  no_start_tbl <- tibble(hiding_spot = "Only node", node_id = "only")
  no_start_fixed <- fn_enforce_one_xcol(no_start_tbl)

  expect_equal(nrow(no_start_fixed), 2L)
  expect_equal(sum(no_start_fixed$clues_to_this_spot == "START", na.rm = TRUE), 1L)

  multi_start_tbl <- make_graph_fixture()
  set.seed(20260320)
  multi_start_fixed <- fn_enforce_one_xcol(multi_start_tbl)

  expect_equal(sum(multi_start_fixed$clues_to_this_spot == "START", na.rm = TRUE), 1L)
  expect_equal(sum(multi_start_fixed$clues_to_this_spot == "FALSE_START", na.rm = TRUE), 1L)
})

test_that("find_eligible_targets matches subcluster overlap semantics", {
  eligible_tbl <- make_graph_fixture() %>%
    mutate(
      clues_to_this_spot = c("START", "Clue B", "Clue G", "Clue D"),
      subcluster_vec = list(c("A"), c("A"), c("A", "B"), c("B"))
    ) %>%
    find_eligible_targets()

  expect_equal(eligible_tbl$eligible_targets[[1]], c(1L, 2L, 3L))
  expect_equal(eligible_tbl$eligible_targets[[2]], c(1L, 2L, 3L))
  expect_equal(eligible_tbl$eligible_targets[[3]], c(1L, 2L, 3L, 4L))
  expect_equal(eligible_tbl$eligible_targets[[4]], c(3L, 4L))
})

test_that("build_graph preserves predefined outgoing nodes and applies current max-edge semantics", {
  raw_tbl <- make_graph_fixture()
  set.seed(20260320)
  normalized_tbl <- raw_tbl %>%
    fn_enforce_one_xcol() %>%
    normalize_graph_fixture()

  set.seed(20260320)
  graph_result <- build_graph(normalized_tbl)
  adj <- graph_result$adj

  incoming_counts <- integer(nrow(normalized_tbl))
  for (targets in adj) {
    if (length(targets) > 0L) {
      incoming_counts[targets] <- incoming_counts[targets] + 1L
    }
  }
  outgoing_counts <- lengths(adj)

  beta_index <- match("beta", normalized_tbl$node_id)
  gamma_index <- match("gamma", normalized_tbl$node_id)

  expect_true(graph_result$is_valid)
  expect_true(gamma_index %in% adj[[beta_index]])
  expect_true(all(outgoing_counts <= normalized_tbl$max_outgoing_edges))
  expect_true(all(incoming_counts <= normalized_tbl$max_incoming_edges))
  expect_true(all(incoming_counts[normalized_tbl$max_incoming_edges > 0L] >= 1L))
})

test_that("build_edge_table and build_dot_string emit the current node and edge layout", {
  normalized_tbl <- make_graph_fixture() %>%
    mutate(clues_to_this_spot = c("START", "Clue B", "Clue G", "Clue D")) %>%
    normalize_graph_fixture()
  adj <- list(c(2L, 3L), 3L, 4L, integer())

  edge_tbl <- build_edge_table(normalized_tbl, adj)
  expect_equal(edge_tbl$from, c("alpha", "alpha", "beta", "gamma"))
  expect_equal(edge_tbl$to, c("beta", "gamma", "gamma", "delta"))
  expect_equal(edge_tbl$from_label, c("Alpha", "Alpha", "Beta", "Gamma"))
  expect_equal(edge_tbl$to_label, c("Beta", "Gamma", "Gamma", "Delta"))

  dot_string <- paste(build_dot_string(normalized_tbl, adj), collapse = "\n")
  expect_match(dot_string, 'alpha [label="Alpha"];', fixed = TRUE)
  expect_match(dot_string, 'delta [label="Delta"];', fixed = TRUE)
  expect_match(dot_string, "alpha -> beta;", fixed = TRUE)
  expect_match(dot_string, "gamma -> delta;", fixed = TRUE)
})

test_that("build_clue_table preserves row count and keeps only atomic columns", {
  normalized_tbl <- make_graph_fixture() %>%
    mutate(clues_to_this_spot = c("START", "Clue B", "Clue G", "Clue D")) %>%
    normalize_graph_fixture()
  adj <- list(c(2L, 3L), 3L, 4L, integer())

  clue_tbl <- build_clue_table(normalized_tbl, adj)

  expect_equal(nrow(clue_tbl), nrow(normalized_tbl))
  expect_true(all(vapply(clue_tbl, is.atomic, logical(1))))
  expect_false("subcluster_vec" %in% names(clue_tbl))
  expect_false("eligible_targets" %in% names(clue_tbl))
  expect_equal(clue_tbl$outgoing_nodes, c("beta:gamma", "gamma", "delta", ""))
})

test_that("run_ebmissions pins current normalized output and file artifacts", {
  input_tbl <- make_graph_fixture()
  input_path <- file.path(tempdir(), "ebmissions-small-input.csv")
  output_dir <- file.path(tempdir(), "ebmissions-small-output")

  if (dir.exists(output_dir)) {
    unlink(output_dir, recursive = TRUE, force = TRUE)
  }

  rio::export(input_tbl, input_path)

  result <- run_ebmissions(
    data_path = input_path,
    output_dir = output_dir,
    seed = 20260320L
  )

  beta_row <- match("beta", result$clue_table$node_id)
  beta_targets <- strsplit(result$clue_table$outgoing_nodes[[beta_row]], ":", fixed = TRUE)[[1]]
  dot_string <- paste(readLines(result$dot_path), collapse = "\n")

  expect_true(file.exists(result$dot_path))
  expect_true(file.exists(result$svg_path))
  expect_true(file.exists(result$csv_path))
  expect_equal(nrow(result$clue_table), nrow(input_tbl))
  expect_equal(sum(result$clue_table$clues_to_this_spot == "START", na.rm = TRUE), 1L)
  expect_equal(sum(result$clue_table$clues_to_this_spot == "FALSE_START", na.rm = TRUE), 1L)
  expect_true("gamma" %in% beta_targets)
  expect_true(all(vapply(result$clue_table, is.atomic, logical(1))))
  expect_match(dot_string, "beta -> gamma;", fixed = TRUE)
})
