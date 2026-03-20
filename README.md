# EBMissions

This repository contains an R script that generates a directed graph of hiding spots for an Easter egg hunt or scavenger hunt.

## Usage

Run the script using `Rscript`:

```bash
Rscript main.R [--data=path/to/input.csv] [--output=output_dir] [--seed=<number>]
```

- `--data`: Optional path to a CSV input file. If omitted, the script uses built-in example data.
- `--output`: Optional output directory (default: `output`).
- `--seed`: Optional random seed to make graph generation reproducible.

## Outputs

The script generates:

- `output/graph.dot` — Graphviz DOT representation of the directed graph.
- `output/graph.svg` — SVG rendering of the directed graph generated with R plotting libraries.
- `output/clue_graph.csv` — A CSV table mapping each hiding spot to the clues it provides.

## Development


Common validation commands:

```bash
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
Rscript main.R --seed=42 --output=output
```

See `CONTRIBUTING.md` for contributor workflow and GitHub issue / pull request guidance.

[![Test coverage](https://raw.githubusercontent.com/bokov/EBMissions/coverage/badges/coverage.svg)](https://github.com/bokov/EBMissions/actions/workflows/test-coverage.yaml)
[![Tests](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
