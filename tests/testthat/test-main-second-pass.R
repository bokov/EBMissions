test_that("main.R can rerun realistic data after half of outgoing nodes are removed", {
  skip_if_not(file.exists("main.R"), "main.R must exist for the end-to-end test.");

  input_path <- file.path(tempdir(), "realistic_input.csv");
  first_output_dir <- file.path(tempdir(), "first_run_output");
  second_input_path <- file.path(tempdir(), "second_pass_input.csv");
  second_output_dir <- file.path(tempdir(), "second_run_output");

  partial_tbl <- make_realistic_partial_input(60L);
  rio::export(partial_tbl, input_path);

  first_run <- system2(
    file.path(R.home("bin"), "Rscript")
    ,c("main.R", paste0("--data=", input_path), paste0("--output=", first_output_dir), "--seed=42")
    ,stdout = TRUE
    ,stderr = TRUE
  );
  expect_equal(if(is.null(attr(first_run, "status"))) 0L else attr(first_run, "status"), 0L);
  expect_true(file.exists(file.path(first_output_dir, "clue_graph.csv")));

  second_pass_tbl <- rio::import(file.path(first_output_dir, "clue_graph.csv"));
  set.seed(99L);
  rows_to_blank <- sample(seq_len(nrow(second_pass_tbl)), ceiling(nrow(second_pass_tbl) / 2));
  second_pass_tbl$outgoing_nodes[rows_to_blank] <- NA_character_;
  rio::export(second_pass_tbl, second_input_path);

  second_run <- system2(
    file.path(R.home("bin"), "Rscript")
    ,c("main.R", paste0("--data=", second_input_path), paste0("--output=", second_output_dir), "--seed=99")
    ,stdout = TRUE
    ,stderr = TRUE
  );
  expect_equal(if(is.null(attr(second_run, "status"))) 0L else attr(second_run, "status"), 0L);
  expect_true(file.exists(file.path(second_output_dir, "graph.dot")));
  expect_true(file.exists(file.path(second_output_dir, "graph.svg")));
  expect_true(file.exists(file.path(second_output_dir, "clue_graph.csv")));

  rerun_tbl <- rio::import(file.path(second_output_dir, "clue_graph.csv"));
  expect_equal(sum(is.na(rerun_tbl$outgoing_nodes)), 0L);
  expect_equal(nrow(rerun_tbl), 60L);
});
