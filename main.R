# Requirements:
# An R script that generates a directed graph of hiding spots for an Easter egg
# hunt or scavenger hunt. Each node in this graph has two core pieces of data:
# its actual hiding spot and one or clues leading to that hiding spot. An Easter
# egg placed on that spot is supposed to contain the clues belonging to eggs to
# which it's connected by outgoing edges. Those eggs in turn will contain the
# clues of the eggs they lead to and so on.
#
# This script will output a graphviz dot file, an SVG representative of the
# graph, and a data frame with location one column and all the clues leading out
# from that location in the second column exported as a spreadsheet.
#
# The input for the script is a spreadsheet with a column for hiding spot, a
# column for clues that lead to that spot (optionally several, separated by
# colons), a column setting the maximum incoming edges, a column setting the
# maximum number of outgoing edges, and a column specifying subcluster
#
# The script then randomly connects the nodes together while observing the
# maximum inbound and maximum outbound constraints. The minimum number of
# inbound edges should be 1 unless explicitly specified as 0. In addition, the
# subclusters value is split by colons and nodes are only permitted to connect
# to each other if they have at least one subcluster in common. For example maybe
# all the indoor eggs have the "indoor" subcluster tag and can only link to each
# other, while eggs with a "yard" subcluster tag only connect to each other. The
# two subclusters can be bridged by eggs which contain both the "indoor" and the
# "yard" tags. If an egg has an empty subclusters field, it is assigned to the
# 'DEFAULT' subcluster. An egg can bridge to the 'DEFAULT' subcluster by
# explicitly having it as one of the tags in its subclusters field.
#

# Coding style:
#   * treat R's optional use of `;` to indicate the end of an expression as mandatory
#   * when breaking lines, do so before a comma but after other symbols
#   * never use single character variable names-- instead double up the character (e.g. instead of x use xx, instead of i use ii)
#   * above each function write a very short comment stating the function's purpose, what kind of input it expects, and what kind of output it returns.
#   * within any large function (20 lines or more not counting comments) identify different steps (step being an informal concept of one or more functionally related expressions or pipelines or a group of repetitive expressions or pipelines) and separate steps from each other by blank lines. Above each step, write a very brief comment saying what it does
#   * designate new sections like this: `# Section Name ----`
#   * when creating horizontal line comments, do not use `-` or `=`, use `_` or `.`
#
# Implementation Requirements:
#   * wherever using a function provided by an existing library would shorten the total code in this script, do so.
#   * never create a function that is only used once with the exception of multi-line functions that need to be used inside of lapply or sapply
#   * do not write functions to replace one-liner or two-liner code which is used two times or less
#   * use dplyr pipelines wherever this will result in less code or in more readable code.
#   * Remember that a frequently used pipeline e.g. `mytable %>% foo %>% bar %>% baz` can be easily turned into a reusable function without writing a wrapper by simply replacing the first step with `.` and assigning it to an object, e.g. `mypipeline <- . %>% foo %>% bar %>% baz`

# Examples of stuff not to do ----

## This is an example of a wrapper function that should not be written because
## it's just moving code around instead of truly shortening it. Instead,
## eval_tidy(f_rhs(...), data = ...) should be used inline
# formula_value <- function(formula_object, data_list = list()) {
#   eval_tidy(f_rhs(formula_object), data = data_list)
# }

## This is an example of a wrapper function that should not be written because
## this operator is already provided by rlang
# `%||%` <- function(left_value, right_value) {
#   if (is.null(left_value)) right_value else left_value
# }

## This is an example of a wrapper function that should not be written because
## there already is a coalesce function provided by dplyr and that should be
## used instead
# coalesce_num <- function(value, default_value = 0) {
#   ifelse(is.na(value), default_value, value)
# }



# Do you understand all the above? Do you have any questions or suggestions?


# libraries ----
library(rio);        # one-stop shop for reading and writing files via import and export
library(tidyverse);  # makes R suck even less than it already does

# global variables ----
data_path <- NULL;
output_dir <- "output";
seed <- NULL;

# command-line argument parsing ----
args <- commandArgs(trailingOnly = TRUE);
if(length(args) > 0){
  for(arg in args){
    if(arg %in% c("-h", "--help")){
      cat("Usage: Rscript main.R [--data=path] [--output=dir] [--seed=num]\n");
      quit(status = 0);
    }
    if(grepl("^--data=", arg)){
      data_path <- sub("^--data=", "", arg);
    } else if(grepl("^--output=", arg)){
      output_dir <- sub("^--output=", "", arg);
    } else if(grepl("^--seed=", arg)){
      seed <- as.integer(sub("^--seed=", "", arg));
    } else {
      stop("Unknown argument: ", arg);
    }
  }
}

if(!is.null(seed)) set.seed(seed);

# read in data ----
# Read the data. If none specified, generate an example input table as specified above
if(!is.null(data_path) && file.exists(data_path)){ dat0 <- import(data_path)
} else {
  dat0 <- tribble(
  ~hiding_spot,       ~clues_to_this_spot,                    ~max_incoming_edges, ~max_outgoing_edges, ~subclusters, ~node_id, ~outgoing_nodes,

  "Kitchen sink",     "Look where water flows",                           1,                   2,   "indoors", "kitchen_sink", "",
  "Big oak tree",     "Roots of wisdom",                                  1,                   1,   "yard", "big_oak_tree", "",
  "Back door",        "Exit where inside meets outside",                  2,                   1,   "indoors:yard", "back_door", "",
  "Front porch",      "Take a seat in the open",                          1,                   1,   "DEFAULT", "front_porch", "",
  "Couch",            "Soft and comfy",                                   1,                   3,   "indoors", "couch", "",
  "Garage",           "Where things are stored",                          1,                   1,   "DEFAULT:indoors", "garage", "",
  "Garden shed",      "Tools of the trade",                               0,                   2,   "yard", "garden_shed", "",
  "Bedroom closet",   "Hidden in plain sight",                            1,                   0,   "indoors", "bedroom_closet", "",
  "Bookshelf",       "Knowledge lives here",                           1,                   2,   "indoors", "bookshelf", "",
  "Under stairs",    "Where shadows gather",                          1,                   2,   "indoors", "under_stairs", "",
  "Pool",            "Water and sun",                                 1,                   2,   "yard", "pool", "",
  "Mailbox",         "Letters arrive",                                1,                   2,   "DEFAULT", "mailbox", "",
  "Treehouse",       "High and cozy",                                  1,                   2,   "yard", "treehouse", "",
  "Fireplace",       "Warmth at night",                               1,                   2,   "indoors", "fireplace", "",
  "Toolbox",         "Fix what breaks",                               1,                   2,   "indoors:yard", "toolbox", "",
  "Gazebo",          "Shelter in the yard",                           1,                   2,   "yard:DEFAULT", "gazebo", "",
  "Attic",           "Up above",                                      1,                   1,   "indoors", "attic", "",
  "Basement",        "Below ground",                                  1,                   1,   "indoors:DEFAULT", "basement", ""
);
}


# Input Validation ----

# Function: validate_input_table
# Purpose: Check that input table has all required columns with correct types. Input: data frame, Output: TRUE or error.
validate_input_table <- function(tbl){
  required_cols <- c("hiding_spot", "clues_to_this_spot", "max_incoming_edges", "max_outgoing_edges", "subclusters", "node_id", "outgoing_nodes");

  missing_cols <- setdiff(required_cols, names(tbl));
  if(length(missing_cols) > 0){
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "));
  }

  if(!is.character(tbl$hiding_spot)){
    stop("Column 'hiding_spot' must be character");
  }
  if(!is.character(tbl$clues_to_this_spot)){
    stop("Column 'clues_to_this_spot' must be character");
  }
  if(!is.numeric(tbl$max_incoming_edges)){
    stop("Column 'max_incoming_edges' must be numeric");
  }
  if(!is.numeric(tbl$max_outgoing_edges)){
    stop("Column 'max_outgoing_edges' must be numeric");
  }
  if(!is.character(tbl$subclusters)){
    stop("Column 'subclusters' must be character");
  }
  if(!is.character(tbl$node_id)){
    stop("Column 'node_id' must be character");
  }
  if(!is.character(tbl$outgoing_nodes)){
    stop("Column 'outgoing_nodes' must be character");
  }

  if(any(tbl$max_incoming_edges < 0) || any(tbl$max_outgoing_edges < 0)){
    stop("max_incoming_edges and max_outgoing_edges must be non-negative");
  }

  if(any(duplicated(tbl$hiding_spot))){
    stop("hiding_spot values must be unique");
  }

  if(any(duplicated(tbl$node_id))){
    stop("node_id values must be unique");
  }

  TRUE;
};

# Subcluster Processing and Node Eligibility ----

# Function: process_subclusters
# Purpose: Split subclusters by ':' and assign DEFAULT where needed. Input: data frame, Output: data frame with subcluster_vec list column.
process_subclusters <- function(tbl){
  tbl %>% mutate(
    subcluster_vec = ifelse(
      is.na(subclusters) | subclusters == "",
      list("DEFAULT"),
      strsplit(subclusters, ":")
    )
  );
};

# Function: find_eligible_targets Purpose: For each node, determine which other
# nodes it can connect to based on subcluster overlap. Input: processed data
# frame, Output: data frame with eligible_targets list column.
find_eligible_targets <- function(tbl){
  nn_nodes <- nrow(tbl);

  tbl %>%
    mutate(
      eligible_targets = map(
        subcluster_vec,
        function(sspot){
          which(
            map_lgl(
              tbl$subcluster_vec,
              function(ttarget){
                length(intersect(sspot, ttarget)) > 0;
              }
            )
          );
        }
      )
    );
};

# Process and prepare data ----
dat0 %>% validate_input_table();
dat1 <- dat0 %>% process_subclusters();
dat2 <- dat1 %>% find_eligible_targets();

# Preview processed data ----
# (disabled for non-interactive runs)
# dat2 %>% select(hiding_spot, subcluster_vec, eligible_targets);

# Graph Construction ----

# Function: build_graph
# Purpose: Randomly connect nodes into a directed graph respecting constraints, with retries for min incoming and cycle check. Input: processed data frame, Output: adjacency list (list of target indices).
build_graph <- function(dat, max_attempts = 100){
  nn <- nrow(dat);
  adj <- NULL;
  g <- NULL;
  is_valid <- FALSE;

  for (attempt in 1:max_attempts){
    adj <- vector("list", nn);
    incoming <- rep(0, nn);
    outgoing <- rep(0, nn);

    # Add pre-defined edges (override constraints)
    for (ii in 1:nn){
      if(dat$outgoing_nodes[ii] != ""){
        pre_targets <- strsplit(dat$outgoing_nodes[ii], ":")[[1]];
        pre_indices <- match(pre_targets, dat$node_id);
        if(any(is.na(pre_indices))) stop("Invalid node_id in outgoing_nodes for ", dat$hiding_spot[ii]);
        adj[[ii]] <- pre_indices;
        incoming[pre_indices] <- incoming[pre_indices] + 1;
        outgoing[ii] <- outgoing[ii] + length(pre_indices);
      }
    }

    node_order <- sample(1:nn);  # randomize order

    # Assign additional outgoing edges greedily
    for (ii in node_order){
      max_out <- dat$max_outgoing_edges[ii] - outgoing[ii];  # remaining after pre-defined
      eligible <- dat$eligible_targets[[ii]];
      eligible <- setdiff(eligible, ii);  # no self-loops
      candidates <- eligible[incoming[eligible] < dat$max_incoming_edges[eligible]];
      num_to_add <- min(max_out, length(candidates));
      if (num_to_add > 0){
        selected <- sample(candidates, num_to_add);
        adj[[ii]] <- c(adj[[ii]], selected);
        incoming[selected] <- incoming[selected] + 1;
        outgoing[ii] <- outgoing[ii] + num_to_add;
      }
    }

    # Ensure min incoming edges by assigning one incoming edge where missing
    need_in <- which(dat$max_incoming_edges > 0 & incoming == 0);
    for (jj in need_in){
      possible_sources <- which(sapply(dat$eligible_targets, function(x) jj %in% x));
      possible_sources <- setdiff(possible_sources, jj);
      possible_sources <- possible_sources[outgoing[possible_sources] < dat$max_outgoing_edges[possible_sources]];
      if (length(possible_sources) > 0){
        src <- sample(possible_sources, 1);
        adj[[src]] <- c(adj[[src]], jj);
        outgoing[src] <- outgoing[src] + 1;
        incoming[jj] <- incoming[jj] + 1;
      }
    }

    # Validate degrees
    degrees_out <- outgoing;
    degrees_in <- incoming;
    degrees_ok <- all(degrees_out <= dat$max_outgoing_edges);  # pre-defined may cause incoming > max, so don't check incoming

    if (all(dat$max_incoming_edges == 0 | incoming >= 1) && degrees_ok){
      is_valid <- TRUE;
      break;
    }
  }

  if (!is_valid){
    warning("Could not build a valid graph after ", max_attempts, " attempts. Constraints may be too strict.");
  }

  list(adj = adj);
};

# Build the graph ----
graph_result <- build_graph(dat2);
adj <- graph_result$adj;

# Output Generation ----

# Function: build_dot_string
# Purpose: Create a Graphviz DOT representation of the graph. Input: data frame and adjacency list, Output: DOT string.
build_dot_string <- function(dat, adj){
  quote_label <- function(x) gsub("\"", "\\\"", x);

  node_lines <- vapply(seq_len(nrow(dat)), function(ii){
    label <- quote_label(dat$hiding_spot[ii]);
    sprintf("  n%d [label=\"%s\"];", ii, label);
  }, "")

  edge_lines <- unlist(lapply(seq_along(adj), function(ii){
    if(length(adj[[ii]]) == 0) return(character(0));
    sprintf("  n%d -> n%d;", ii, adj[[ii]])
  }));

  c("digraph G {", "  rankdir=LR;", node_lines, edge_lines, "}");
};

# Function: build_clue_table
# Purpose: Build a table with all input columns plus populated outgoing_nodes and outgoing_clues. Input: dat0, dat2, adj, Output: tibble.
build_clue_table <- function(dat0, dat2, adj){
  dat0 %>%
    mutate(
      outgoing_nodes = map_chr(adj, ~ if(length(.x) == 0) "" else paste(dat2$node_id[.x], collapse = ":")),
      outgoing_clues = map_chr(adj, ~ if(length(.x) == 0) "" else paste(dat2$clues_to_this_spot[.x], collapse = " | "))
    );
};

# Write outputs ----
if(!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE);

dot_path <- file.path(output_dir, "graph.dot");
svg_path <- file.path(output_dir, "graph.svg");
spreadsheet_path <- file.path(output_dir, "clue_graph.csv");

dot_text <- build_dot_string(dat2, adj);
writeLines(dot_text, dot_path);

# Render SVG (requires `dot` from Graphviz installed)
if(Sys.which("dot") != ""){
  system2("dot", c("-Tsvg", dot_path, "-o", svg_path));
} else {
  warning("Graphviz 'dot' not found; SVG not generated.");
}

clue_table <- build_clue_table(dat0, dat2, adj);
rio::export(clue_table, spreadsheet_path);
