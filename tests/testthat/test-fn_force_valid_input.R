test_that("fn_force_valid_input repairs the worst-case input shape", {
  worst_tbl <- make_worst_case_input(60L);
  fixed_tbl <- fn_force_valid_input(worst_tbl);

  expect_equal(nrow(fixed_tbl), 60L);
  expect_true(all(names(data_spec) %in% names(fixed_tbl)));
  expect_equal(sum(is.na(fixed_tbl$outgoing_nodes)), 0L);
  expect_true(all(fixed_tbl$max_incoming_edges >= 0L));
  expect_true(all(fixed_tbl$max_outgoing_edges >= 0L));
  expect_equal(length(unique(fixed_tbl$node_id)), 60L);
  expect_true(all(fixed_tbl$subclusters == "DEFAULT"));
});

test_that("fn_force_valid_input repairs realistic partial data and preserves extras", {
  partial_tbl <- make_realistic_partial_input(60L);
  fixed_tbl <- fn_force_valid_input(partial_tbl);

  expect_equal(nrow(fixed_tbl), 60L);
  expect_true(all(c("extra_notes", "priority_hint") %in% names(fixed_tbl)));
  expect_true(all(names(data_spec) %in% names(fixed_tbl)));
  expect_equal(sum(is.na(fixed_tbl$outgoing_nodes)), 0L);
  expect_true(any(fixed_tbl$max_incoming_edges == 0L));
  expect_true(all(fixed_tbl$max_incoming_edges >= 0L));
  expect_true(all(fixed_tbl$max_outgoing_edges >= 0L));
  expect_true(any(str_detect(fixed_tbl$subclusters, ":")));
  expect_true(any(fixed_tbl$subclusters == "DEFAULT"));
  expect_equal(length(unique(fixed_tbl$node_id)), 60L);
});

test_that("fn_force_valid_input keeps ideal input valid while filling allowed gaps", {
  ideal_tbl <- make_ideal_input(60L);
  fixed_tbl <- fn_force_valid_input(ideal_tbl);

  expect_equal(nrow(fixed_tbl), 60L);
  expect_equal(sum(is.na(fixed_tbl$outgoing_nodes)), 0L);
  expect_true(any(fixed_tbl$subclusters == "DEFAULT"));
  expect_true(any(str_detect(fixed_tbl$subclusters, "DEFAULT:")));
  expect_equal(length(unique(fixed_tbl$node_id)), 60L);
  expect_true(all(fixed_tbl$hiding_spot != ""));
});
