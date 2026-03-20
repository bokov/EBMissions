# Shared constants and functions for the EBMissions graph generator.

# libraries ____
library(rio);
library(tidyverse);

# global defaults ____
data_spec <- tibble(
  hiding_spot = "MISSING"
  ,clues_to_this_spot = "MISSING"
  ,max_incoming_edges = 3
  ,max_outgoing_edges = 3
  ,subclusters = "DEFAULT"
  ,node_id = ""
  ,outgoing_nodes = ""
);

# This function builds example input data. Input: NULL. Output: tibble.
create_example_input <- function(){
  tribble(
    ~hiding_spot,       ~clues_to_this_spot,                    ~max_incoming_edges, ~max_outgoing_edges, ~subclusters,        ~node_id,           ~outgoing_nodes
    ,"Kitchen sink",   "Look where water flows",             1,                   2,                   "indoors",         "kitchen_sink",    ""
    ,"Big oak tree",   "Roots of wisdom",                    1,                   1,                   "yard",            "big_oak_tree",    ""
    ,"Back door",      "Exit where inside meets outside",    2,                   1,                   "indoors:yard",    "back_door",       ""
    ,"Front porch",    "Take a seat in the open",            1,                   1,                   "DEFAULT",         "front_porch",     ""
    ,"Couch",          "Soft and comfy",                     1,                   3,                   "indoors",         "couch",           ""
    ,"Garage",         "Where things are stored",            1,                   1,                   "DEFAULT:indoors", "garage",          ""
    ,"Garden shed",    "Tools of the trade",                 0,                   2,                   "yard",            "garden_shed",     ""
    ,"Bedroom closet", "Hidden in plain sight",              1,                   0,                   "indoors",         "bedroom_closet",  ""
    ,"Bookshelf",      "Knowledge lives here",               1,                   2,                   "indoors",         "bookshelf",       ""
    ,"Under stairs",   "Where shadows gather",               1,                   2,                   "indoors",         "under_stairs",    ""
    ,"Pool",           "Water and sun",                      1,                   2,                   "yard",            "pool",            ""
    ,"Mailbox",        "Letters arrive",                     1,                   2,                   "DEFAULT",         "mailbox",         ""
    ,"Treehouse",      "High and cozy",                      1,                   2,                   "yard",            "treehouse",       ""
    ,"Fireplace",      "Warmth at night",                    1,                   2,                   "indoors",         "fireplace",       ""
    ,"Toolbox",        "Fix what breaks",                    1,                   2,                   "indoors:yard",    "toolbox",         ""
    ,"Gazebo",         "Shelter in the yard",                1,                   2,                   "yard:DEFAULT",    "gazebo",          ""
    ,"Attic",          "Up above",                           1,                   1,                   "indoors",         "attic",           ""
    ,"Basement",       "Below ground",                       1,                   1,                   "indoors:DEFAULT", "basement",        ""
  );
}


# This function coerces a table into valid input. Input: data frame and optional
# spec tibble. Output: tibble. This function was put here by a human dev
# and is a drop-in replacement for the lengthy function that was here
# previously. Do not undo this!!!
fn_force_valid_input <- function(data,spec=data_spec){
  vctrs::vec_cast_common(data,spec)[[1]] %>%
    mutate(across(any_of(setdiff(names(spec),'node_id')),~ coalesce(.x,spec[[cur_column()]]))
           ,across(ends_with('_edges'),~ifelse(.x<0,spec[[cur_column()]],.x))
           # half assed dynamic generation of node_ids
           ,temp_node_id = make.unique(sapply(str_extract_all(tolower(hiding_spot), "\\w+"), \(x) paste(head(x, 3), collapse = "_")), sep = "_")
           ,node_id = coalesce(node_id,temp_node_id)
           # the temp_node_id is no longer needed, so remove
           ,temp_node_id = NULL)
}

# ensures that the data has a column of the specified name (x_column) with
# exactly one instance of the specified value (x_value) in that column. If there
# are none, a synthetic row is added (with NAs in all the other columns) and if
# there are several one is randomly selected to keep and the others are replaced
# with nonx_value
fn_enforce_one_xcol <- function(data,x_column='clues_to_this_spot'
                                 ,x_value='START'
                                 ,nonx_value='FALSE_START'){
  # If the column is not found, create it
  if(!x_column %in% names(data)) data[[x_column]] <- NA;
  # How many times was x_value found in x_column?
  nstarts <- sum(data[[x_column]]==x_value,na.rm = T);
  # If it wasn't found, add a synthetic row with x_column populated and the
  # rest of the row as NAs
  if(nstarts==0) return(rbind(data,mutate(data[0,][1,],!!x_column:='START')));
  # If it was found once, we're done, return the data as-is
  if(nstarts==1) return(data);
  # Otherwise, randomly select one instance of x_value to keep and replace the rest with nonx_value
  mutate(data,!!x_column:=replace(.data[[x_column]]
                              ,which(.data[[x_column]]==x_value) %>% setdiff(.,sample(.,1)),nonx_value))
}

# obtains all unique values of subcluster_vec and uses grepl to match subtables
# which implicitly duplicates them (if passthrough is set to F)
# not yet used
fn_split_tbl_by_subcluster <- function(data
                                       ,sc_column='subcluster_vec'
                                       ,default_val='DEFAULT',passthrough=T){
  # right now this is just a no-op capable preparatory layer
  if(passthrough) return(list(PASSTHROUGH=data));
  data[[sc_column]] %>% unlist %>% unique %>%
    sapply(function(xx) subset(data,grepl(xx,data[[sc_column]])),simplify=F)
};

# This function finds target nodes permitted by subclusters. Input: processed tibble. Output: tibble.
find_eligible_targets <- function(tbl){
  tbl %>%
    mutate(
      eligible_targets = map(
        subcluster_vec
        ,function(source_subclusters){
          which(
            map_lgl(
              tbl$subcluster_vec
              ,function(target_subclusters){
                length(intersect(source_subclusters, target_subclusters)) > 0;
              }
            )
          );
        }
      )
    );
}

# This function randomly builds adjacency lists. Input: processed tibble and attempts. Output: named list.
build_graph <- function(dat, max_attempts = 100L){
  nn_rows <- nrow(dat);
  final_adj <- vector("list", nn_rows);
  graph_valid <- FALSE;

  # Try multiple randomized passes.
  for(attempt in seq_len(max_attempts)){
    adj <- vector("list", nn_rows);
    incoming_counts <- integer(nn_rows);
    outgoing_counts <- integer(nn_rows);

    # Respect any predefined edges first.
    for(ii in seq_len(nn_rows)){
      if(dat$outgoing_nodes[[ii]] != ""){
        target_ids <- strsplit(dat$outgoing_nodes[[ii]], ":")[[1]];
        target_indices <- match(target_ids, dat$node_id);

        if(any(is.na(target_indices))){
          stop("Invalid node_id in outgoing_nodes for ", dat$hiding_spot[[ii]]);
        }

        adj[[ii]] <- unique(target_indices);
        incoming_counts[target_indices] <- incoming_counts[target_indices] + 1L;
        outgoing_counts[[ii]] <- length(adj[[ii]]);
      }
    }

    # Fill remaining outgoing edges.
    for(ii in sample(seq_len(nn_rows))){
      remaining_outgoing <- dat$max_outgoing_edges[[ii]] - outgoing_counts[[ii]];
      if(remaining_outgoing <= 0L){
        next;
      }

      eligible_indices <- setdiff(dat$eligible_targets[[ii]], ii);
      candidate_indices <- eligible_indices[incoming_counts[eligible_indices] < dat$max_incoming_edges[eligible_indices]];
      candidate_indices <- setdiff(candidate_indices, adj[[ii]]);
      edges_to_add <- min(remaining_outgoing, length(candidate_indices));

      if(edges_to_add > 0L){
        selected_indices <- sample(candidate_indices, edges_to_add);
        adj[[ii]] <- c(adj[[ii]], selected_indices);
        incoming_counts[selected_indices] <- incoming_counts[selected_indices] + 1L;
        outgoing_counts[[ii]] <- outgoing_counts[[ii]] + edges_to_add;
      }
    }

    # Backfill nodes missing required incoming edges.
    required_targets <- which(dat$max_incoming_edges > 0L & incoming_counts == 0L);
    for(jj in required_targets){
      possible_sources <- which(map_lgl(dat$eligible_targets, function(xx) jj %in% xx));
      possible_sources <- setdiff(possible_sources, jj);
      possible_sources <- possible_sources[outgoing_counts[possible_sources] < dat$max_outgoing_edges[possible_sources]];
      possible_sources <- possible_sources[!map_lgl(adj[possible_sources], function(xx) jj %in% xx)];

      if(length(possible_sources) > 0L){
        source_index <- sample(possible_sources, 1);
        adj[[source_index]] <- c(adj[[source_index]], jj);
        outgoing_counts[[source_index]] <- outgoing_counts[[source_index]] + 1L;
        incoming_counts[[jj]] <- incoming_counts[[jj]] + 1L;
      }
    }

    # Stop once constraints are satisfied.
    if(all(dat$max_incoming_edges == 0L | incoming_counts >= 1L) && all(outgoing_counts <= dat$max_outgoing_edges)){
      final_adj <- map(adj, unique);
      graph_valid <- TRUE;
      break;
    }
  }

  if(!graph_valid){
    warning("Could not build a valid graph after ", max_attempts, " attempts. Constraints may be too strict.");
    final_adj <- map(final_adj, unique);
  }

  list(adj = final_adj, is_valid = graph_valid);
}

# This function converts adjacency lists into an edge table. Input: tibble and adjacency list. Output: tibble.
build_edge_table <- function(dat, adj){
  edge_rows <- map2_dfr(
    seq_along(adj)
    ,adj
    ,function(source_index, target_indices){
      if(length(target_indices) == 0L){
        return(tibble(from = character(), to = character(), from_label = character(), to_label = character()));
      }

      tibble(
        from = dat$node_id[[source_index]]
        ,to = dat$node_id[target_indices]
        ,from_label = dat$hiding_spot[[source_index]]
        ,to_label = dat$hiding_spot[target_indices]
      );
    }
  );

  edge_rows;
}

# This function builds DOT text. Input: tibble and adjacency list. Output: character vector.
build_dot_string <- function(dat, adj){
  quote_label <- function(xx){
    gsub('"', '\\\\"', xx);
  };

  node_lines <- vapply(
    seq_len(nrow(dat))
    ,function(ii){
      sprintf(
        "  %s [label=\"%s\"];"
        ,dat$node_id[[ii]]
        ,quote_label(dat$hiding_spot[[ii]])
      );
    }
    ,character(1)
  );

  edge_tbl <- build_edge_table(dat, adj);
  edge_lines <- if(nrow(edge_tbl) == 0L){
    character();
  } else {
    sprintf("  %s -> %s;", edge_tbl$from, edge_tbl$to);
  };

  c("digraph G {", "  rankdir=LR;", node_lines, edge_lines, "}");
}

# This function writes an SVG visualization. Input: tibble, adjacency list, and path. Output: path string.
write_svg_graph <- function(dat, adj, svg_path){
  vertices_tbl <- dat %>% select(name = node_id, label = hiding_spot);
  edges_tbl <- build_edge_table(dat, adj) %>% select(from, to);
  graph_obj <- igraph::graph_from_data_frame(edges_tbl, directed = TRUE, vertices = vertices_tbl);

  # Compute layout and draw into an SVG device.
  graph_layout <- igraph::layout_nicely(graph_obj);
  svglite::svglite(file = svg_path, width = 12, height = 8);
  on.exit(grDevices::dev.off(), add = TRUE);
  graphics::par(mar = c(0.2, 0.2, 0.2, 0.2));
  plot(
    graph_obj
    ,layout = graph_layout
    ,vertex.label = igraph::V(graph_obj)$label
    ,vertex.label.cex = 0.8
    ,vertex.size = 26
    ,vertex.color = "#F8D568"
    ,vertex.frame.color = "#8A5A00"
    ,edge.arrow.size = 0.35
    ,edge.color = "#555555"
  );

  # nobody cares about svg_path, but the graph object and the ingredients that
  # went into making it are useful, so that's what we'll return
  list(vertices_tbl=vertices_tbl,edges_tbl=edges_tbl,graph_layout=graph_layout,graph_obj=graph_obj);
}

# This function builds the output clue table. Input: normalized input and adjacency list. Output: tibble.
build_clue_table <- function(normalized_dat, adj){
  normalized_dat %>%
    mutate(
      outgoing_nodes = map_chr(adj, ~ if(length(.x) == 0L) "" else paste(normalized_dat$node_id[.x], collapse = ":"))
    );
}

# This function reads input data or creates sample data. Input: optional path. Output: tibble.
read_input_data <- function(data_path = NULL){
  if(!is.null(data_path) && file.exists(data_path)){
    return(import(data_path));
  }

  create_example_input();
}

# This function runs the complete pipeline. Input: optional data path, output dir, and seed. Output: named list.
run_ebmissions <- function(data_path = NULL, output_dir = "output", seed = NULL){
  if(!is.null(seed)){
    set.seed(seed);
  }

  # This is the input normalization step that attempts to ensure that the data
  # is in the required format and there is exactly one node whose
  # clues_to_this_spot value is 'START' and then creates the subcluster_vec
  # without needing a dedicated function for it. Finally, it gets piped through
  # find_eligible_targets
  processed_dat <- read_input_data(data_path = data_path) %>%
    fn_enforce_one_xcol %>% fn_force_valid_input %>%
    # this replaces process_subclusters... this is what I mean by don't write
    # a function where a short expression will do!
    mutate(subcluster_vec=lapply(subclusters
                                 ,function(xx) unique(strsplit(xx,':')[[1]]))) %>%
    find_eligible_targets;

  graph_result <- build_graph(processed_dat);
  adj <- graph_result$adj;

  if(!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE);

  dot_path <- file.path(output_dir, "graph.dot");
  svg_path <- file.path(output_dir, "graph.svg");
  csv_path <- file.path(output_dir, "clue_graph.csv");

  writeLines(build_dot_string(processed_dat, adj), dot_path);
  graph_stuff <- write_svg_graph(processed_dat, adj, svg_path);
  clue_table <- build_clue_table(normalized_dat, adj);
  rio::export(clue_table, csv_path);

  list(
    dot_path = dot_path
    ,svg_path = svg_path
    ,csv_path = csv_path
    ,clue_table = clue_table
    ,graph_stuff = graph_stuff
    ,graph_valid = graph_result$is_valid
  );
}
