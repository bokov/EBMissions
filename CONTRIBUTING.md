# Contributing to EBMissions

Thanks for contributing.

## Project shape

This repository is currently a script-first R project centered on `main.R`, with reusable helpers in `R/ebmissions_core.R`.

## Required tools

The recommended development environment is the checked-in dev container / GitHub Codespaces configuration.

At a minimum, contributors should have:

- R
- the CRAN packages required by this code
- GitHub CLI (`gh`) if they want to create or resolve GitHub issues from the terminal

## Local workflow

1. Create or pick up a GitHub issue.
2. Make the smallest change that satisfies the issue.
3. Run the automated checks listed below.
4. Update documentation and issue state if behavior changed.
5. Open a pull request that links the issue with a closing keyword such as `Closes #123`.

## Coding expectations

- Keep repo-wide workflow guidance in this file so it stays useful to humans, Copilot, and other coding agents.
- Keep code-specific R conventions in the source files where they are most relevant.
- Prefer small, reviewable pull requests.
- If code behavior changes, update any affected documentation and issue acceptance criteria in the same change.
- Do not open a pull request from a knowingly broken branch unless a human explicitly asks for that override.
- Prefer fixing existing bugs in the touched area before expanding scope with new features.

## R style conventions

- Terminate expressions with semicolons in project R files.
- Prefer descriptive variable names instead of single-character names.
- Add a short purpose / input / output comment immediately above each function.
- In larger functions, separate major steps with blank lines and a brief step comment.
- Prefer pipelines where they improve readability.
- Use repo-level documents such as this file for shared workflow rules, and keep code-local implementation notes near the code they govern.

## Automated checks

Run these from the repository root when the tools are available:

```bash
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
Rscript main.R --seed=42 --output=output
```

## Task tracking

The canonical backlog should live in GitHub Issues and, if used, GitHub Projects.

Recommended issue contents:

- goal
- context / why
- acceptance criteria
- validation steps
- out-of-scope notes

## Documentation sync

When you change code, update the relevant documentation in the same branch when any of the following change:

- command-line arguments
- outputs written by the script
- dependency expectations
- contributor workflow

## GitHub issue operations

To create or close issues from a terminal session, the environment must:

- be connected to the GitHub repository via `git remote`
- have `gh` installed
- have GitHub authentication configured for an account or token with the needed repository permissions

## Recommended branch hygiene

- Sync from `origin` before starting substantial work.
- Rebase or merge from the default branch regularly on long-lived branches.
- Link each pull request to the issue it resolves.
