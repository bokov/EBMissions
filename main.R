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

# read in data ----
# Read the data. If none specified, generate an example input table as specified above
if(!is.null(data_path) && file.exists(data_path)){ dat0 <- import(data_path)
} else {
  dat0 <- tribble(
  ~hiding_spot,       ~clues_to_this_spot,                    ~max_incoming_edges, ~max_outgoing_edges, ~subclusters,

  "Kitchen sink",     "Look where water flows",                           1,                   2,   "indoors",
  "Big oak tree",     "Roots of wisdom",                                  1,                   1,   "yard",
  "Back door",        "Exit where inside meets outside",                  2,                   1,   "indoors:yard",
  "Front porch",      "Take a seat in the open",                          1,                   1,   "DEFAULT",
  "Couch",            "Soft and comfy",                                   1,                   3,   "indoors",
  "Garage",           "Where things are stored",                          1,                   1,   "DEFAULT:indoors",
  "Garden shed",      "Tools of the trade",                               0,                   2,   "yard",
  "Bedroom closet",   "Hidden in plain sight",                            1,                   0,   "indoors"
);
}


# Input Validation ----

# Function: validate_input_table
# Purpose: Check that input table has all required columns with correct types. Input: data frame, Output: TRUE or error.
validate_input_table <- function(tbl){
  required_cols <- c("hiding_spot", "clues_to_this_spot", "max_incoming_edges", "max_outgoing_edges", "subclusters");

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

  if(any(tbl$max_incoming_edges < 0) || any(tbl$max_outgoing_edges < 0)){
    stop("max_incoming_edges and max_outgoing_edges must be non-negative");
  }

  if(any(duplicated(tbl$hiding_spot))){
    stop("hiding_spot values must be unique");
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
dat2 %>% select(hiding_spot, subcluster_vec, eligible_targets);
