# This is basically going to be a replacement for the existing code. It's in
# a separate file because I didn't want to overwrite the previous code yet.
# But some of the functions may have the same names as the ones used in
# main.R and ebmissions_core.R, so do not run this script and those in the same
# R session or they may collide. Restart R between running this one and those.

# Instructions
#
# 1. Source this script
# 2. Import your data via, e.g. my_data <- import('path/to/my_data.xlsx');
# 3. Run this pipeline of commands:
#    my_data %>% fn_force_valid_input %>% fn_df2grph %>% fn_grphConnLinear %>% fn_grph_vnEdit()
# 4. You will have a web-app open in your browser allowing you to edit the labels
#    and break/reassign connections as you see fit.
# 5. When you are done, click 'Save'. This will exit and make fn_grph_vnEdit
#    save the modified data in a data.frame by default called vnedit_out in your
#    global R environment.
# 6. You can save vnedit_out with export(vnedit_out, file='my_modified_data.xlsx');
# 7. Or, you can keep working on it using standard dplyr commands or converting
#    it to an igraph via fn_df2grph(vnedit_out). If your graph has multiple
#    disconnected pieces, you can pipe it through fn_grphConnLinear again to
#    randomly paste them all back into one connected piece again
#    (fn_grphConnLinear's output is also an igraph). If you want to interactively
#    edit it some smore, send it to fn_grph_vnEdit again. Keep iterating until
#    you are happy with your graph.
# 8. If you want to export a printable data.frame in a convenient order where
#    the first column is the location of each egg and the second column is for
#    the clue/s the egg contains, run any data.frame through fn_makeClueSheet

# TODO
# DONE Update data_spec based on the current sample_df0 plus outgoing_nodes
# DONE the core workflow is now:
#   DF %>% fn_force_valid_input %>% fn_df2grph %>% fn_grphConnLinear %>% fn_grph_viEdit()
#   Thoroughly test these
# * Make a convenience label-printing function (name, label, outgoing_clues)
# * update instructions


# libraries ----
library(rio);
library(tidyverse);
library(igraph);
library(ggraph);
library(lorem);
library(visNetwork);
library(shiny);

# global defaults ----
data_spec <- tibble(
  name = "missing"
  ,label="Missing"
  ,clues_to_this_spot = "Clue is missing."
  ,subcluster = "DEFAULT"
  ,outgoing_nodes = ""
  ,outgoing_clues = ""
);

# new test table
sample_df0 <- tribble(
  ~name,               ~label,                            ~clues_to_this_spot,                ~subcluster,
  "under_the_sink",    "Under the kitchen sink",          "Check behind the cleaning supplies.", "Kitchen",
  "behind_the_curtain","Behind the velvet curtain",       "Look where the light is blocked.",    "Living",
  "inside_the_oven",   "Inside the cold oven",            "A place for baking, but not today.",  "Kitchen",
  "top_of_bookshelf",  "Top of the mahogany bookshelf",   "High above the literature.",          NA,
  "behind_the_fridge", "Behind the refrigerator",         "It is humming loudly here.",          "Kitchen",
  "under_the_rug",     "Under the Persian rug",           "Watch your step for a bump.",         NA,
  "inside_the_piano",  "Inside the grand piano",          "Between the hammers and strings.",    NA,
  "behind_the_mirror", "Behind the ornate mirror",        "Reflections aren't all that's here.", "Bedroom",
  "under_the_stairs",  "Under the basement stairs",       "Down in the dusty dark.",             NA,
  "inside_the_clock",  "Inside the grandfather clock",    "Listen for the ticking gears.",       NA,
  "behind_the_shed",   "Behind the garden shed",          "Where the lawnmower sleeps.",         NA,
  "under_the_bench",   "Under the wooden garden bench",   "Near the blooming roses.",            "Garden",
  "inside_the_trunk",  "Inside the cedar trunk",          "Smells like old clothes and wood.",   NA,
  "top_of_wardrobe",   "Top of the bedroom wardrobe",     "Gathering dust near the ceiling.",    NA,
  "behind_the_tv",     "Behind the flat screen TV",       "Lost in a web of cables.",            NA,
  "under_the_deck",    "Under the outdoor deck",          "Among the spiderwebs and dirt.",      "Garden",
  "inside_the_chimney","Inside the soot-covered chimney", "Santa's favorite entry point.",       NA,
  "behind_the_sofa",   "Behind the leather sofa",         "Where the remote usually goes.",      "Living",
  "under_the_mattress","Under the queen mattress",        "A very flat hiding place.",           "Bedroom",
  "inside_the_toolbox","Inside the heavy toolbox",        "Between the wrench and hammer.",      NA,
  "behind_the_dryer",  "Behind the laundry dryer",        "Warm and full of lint.",              NA
)

# utility functions ----

# This function coerces a table into valid input. Input: data frame and optional
# spec tibble. Output: tibble. This function was put here by a human dev
# and is a drop-in replacement for the lengthy function that was here
# previously. Do not undo this!!!
fn_force_valid_input <- function(data,spec=data_spec){
  vctrs::vec_cast_common(data,spec)[[1]] %>%
    mutate(across(any_of(setdiff(names(spec),'node_id')),~ coalesce(.x,spec[[cur_column()]]))
           ,name=make.unique(name) %>% gsub('\\.','_',.)) %>%
    relocate(name)}


# makes a data.frame from an igraph
fn_df2grph <- function(df){
  # vertices
  # remove outgoing_nodes, outgoing_clues
  vertices <- mutate(df,outgoing_nodes=NULL,outgoing_clues=NULL,to=NULL,from=NULL);
  # edges
  edges <- subset(df,coalesce(outgoing_nodes,'')!='') %>%
    transmute(from=name,to=outgoing_nodes) %>% separate_rows('to',sep=':') %>%
    left_join(df[,c('name','clues_to_this_spot')],by=c(to='name')) %>%
    rename(label=clues_to_this_spot);
  graph_from_data_frame(edges,vertices=vertices);
}

# makes an igraph from a data.frame
fn_grph2df <- function(grph){
  as_data_frame(grph,what='both') %>%
    with(group_by(edges,from) %>%
           summarise(outgoing_nodes=paste0(to,collapse=':')
                     ,outgoing_clues=paste0(label,collapse=':')) %>%
           left_join(vertices,.,by=c(name='from')));
}

# make a data.frame from the nodes and vertices obtained from visNetwork
fn_ne2df <- function(nodes,edges){
  nodes <- mutate(nodes,name=id,id=NULL) %>%
    relocate(name);
  out <- group_by(edges,from) %>%
    summarise(outgoing_nodes=paste0(to,collapse=':')
              ,outgoing_clues=paste0(label,collapse=':')) %>%
    left_join(nodes,.,by=c(name='from'))
  if('border' %in% names(out)) rename(out, frame.color=border) else out;
}

# creates a data.frame of various useful graph properties
fn_grph_details  <-  function(grph){
  if(is.null(V(grph)$name)) stop('The user-supplied graph must have node names.');
  with(components(grph)
       ,data.frame(name=names(membership)
                   ,component=membership
                   ,csize=csize[membership])) %>%
    mutate(inbound=degree(grph,mode='in')
           ,outbound=degree(grph,mode='out')
           ,total=inbound+outbound
    ) %>%
    cbind(subcluster=coalesce(V(grph)$subcluster,NA))
};

fn_makeClueSheet <- . %>% fn_force_valid_input() %>%
  select(all_of(c('label','outgoing_clues'))
         ,any_of(c('subcluster','name','outgoing_nodes'))) %>%
  separate_rows('outgoing_clues',sep=':');


# takes a disconnected igraph and makes it connected. If all the fragments
# are non-branching, the result is also non-branching
fn_grphConnLinear <- function(grph){
  info_grph <- fn_grph_details(grph);
  while(length(unique(info_grph$component))>1){
    eligible_leaves <- subset(info_grph,outbound==0);
    if(any(eligible_leaves$subcluster!='DEFAULT')){
      eligible_leaves <- subset(eligible_leaves,subcluster!='DEFAULT')};
    # pick a vertex with 0 outbound that is not DEFAULT
    # if there are none, pick one that is DEFAULT
    leaf2link <- slice_sample(eligible_leaves,n=1);
    # pick another vertex with 0 inbound that is the same subcluster and a different component
    # if there are none, pick another vertex with 0 inbound that is a different component
    eligible_roots <- subset(info_grph,inbound==0 & component != leaf2link$component);
    if(length(eligible_roots)==0) browser();
    if(any(eligible_roots$subcluster==leaf2link$subcluster)){
      eligible_roots <- subset(eligible_roots,subcluster==leaf2link$subcluster)};
    root2link <- slice_sample(eligible_roots,n=1);
    grph <- add_edges(grph,c(leaf2link$name,root2link$name));
    info_grph <- fn_grph_details(grph);
    # add edge between first vertex and second vertex
    # re-run fn_grph_details
  }
  # mark subclusters with contour color
  V(grph)$frame.color <- rainbow(length(unique(V(grph)$subcluster)))[factor(V(grph)$subcluster)];
  # a hacky way to make sure all edges are labeled
  fn_grph2df(grph) %>% fn_df2grph();
}

fn_grph_vnEdit <- function(grph,df,resultname='vnedit_out'){
  # 1. Prepare data
  v_data <- toVisNetworkData(grph,idToLabel = F);

  ui <- fluidPage(
    visNetworkOutput("network", height = "80vh"),
    actionButton("save", "Save and Exit")
  );

  server <- function(input, output, session) {
    output$network <- renderVisNetwork({
      visNetwork(v_data$nodes %>% rename(color.border=frame.color)
                 , v_data$edges ) %>%
        visEdges(arrows = "to", font=list(align='top',size=8),widthConstraint=list(maximum=80)) %>%
        visNodes(shape='box',widthConstraint = list(maximum = 70),size = 70, font = list(size = 12)) %>%
        visOptions(manipulation = TRUE) # This enables the 'Delete' toolbar
    });

    observeEvent(input$save, {
      # This magic line grabs the current state from the browser
      visNetworkProxy("network") %>% visGetNodes() %>% visGetEdges()
    });

    observe({
      # When the proxy returns the data, save it to the global environment
      if(!is.null(input$network_nodes) & !is.null(input$network_edges)){
        nodes <- do.call(bind_rows, lapply(input$network_nodes, as.data.frame));
        edges <- do.call(bind_rows, lapply(input$network_edges, as.data.frame));
        assign(resultname, fn_ne2df(nodes,edges), envir = .GlobalEnv)
        stopApp()
      }
    })
  }

  runApp(list(ui = ui, server = server))
}

