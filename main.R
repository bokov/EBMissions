# Entry point for the EBMissions graph generator.

source(file.path("R", "ebmissions_core.R"));

# This function parses command-line arguments. Input: character vector. Output: named list.
parse_command_line_args <- function(args){
  data_path <- NULL;
  output_dir <- "output";
  seed <- NULL;

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

  list(data_path = data_path, output_dir = output_dir, seed = seed);
}

# Run the script when executed directly. Input: commandArgs output. Output: output file list.
main <- function(){
  run_args <- parse_command_line_args(commandArgs(trailingOnly = TRUE));
  run_ebmissions(
    data_path = run_args$data_path
    ,output_dir = run_args$output_dir
    ,seed = run_args$seed
  );
}

main();
