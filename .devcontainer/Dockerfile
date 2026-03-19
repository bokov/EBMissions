# Dev Container for R development with GitHub CLI and SVG graph output support.
FROM rocker/r-ver:latest

# Install system dependencies and GitHub CLI.
RUN apt-get update && \
    apt-get install -y \
      curl \
      git \
      gh \
      libcurl4-openssl-dev \
      libssl-dev \
      libxml2-dev \
      libxt-dev \
      libfontconfig1-dev \
      libharfbuzz-dev \
      libfribidi-dev \
      libfreetype6-dev \
      libpng-dev \
      libglpk-dev \
      libgmp3-dev \
      && rm -rf /var/lib/apt/lists/*

# Install R packages.
RUN R -e "install.packages(c('shinyjs', 'cookies', 'bslib', 'googlesheets4', 'tidyverse', 'rio', 'ggplot2', 'vctrs', 'igraph', 'svglite', 'testthat'), repos = 'https://cloud.r-project.org/')"

# Set default workdir.
WORKDIR /workspaces/EBMissions
