# Repository Guidelines

## Project Structure & Module Organization

`cashomon` is an R package implementing TruVaRImp search and permutation feature importance across near-optimal models.

- `R/` is flat: `truvarimp.R` and `kernel.R` implement search; `candidates.R`, `fit.R`, `pfi.R`, and `plots.R` handle the model workflow. Internal helpers live in `utils.R`.
- `NAMESPACE` and `man/` are generated from roxygen comments in `R/`.
- `tests/testthat/` contains component tests and shared fixtures; `tests/testthat.R` runs the suite.
- `vignettes/cashomon.Rmd` explains usage; `inst/examples/` contains runnable workflows. Example outputs go into `artifacts/`.
- `.github/workflows/R-CMD-check.yaml` runs documentation generation, package checks, and the regression example.

## Build, Test, and Development Commands

Use R 4.1 or newer. Install dependencies listed in `DESCRIPTION`; vignette rendering also requires Pandoc. Run commands from the repository root:

```sh
Rscript tools/document.R            # Regenerate NAMESPACE and help pages
Rscript -e 'testthat::test_local()'  # Run development tests
R CMD build .                      # Build the source archive
R CMD check cashomon_0.1.0.tar.gz --no-manual
R CMD INSTALL .                    # Install before running examples
Rscript inst/examples/workflow.R    # Export model scores, PFI, and figures
```

Match the archive filename to the version in `DESCRIPTION`. Consult `VALIDATION.md` for previously skipped checks; restricted checks do not establish full integration success.

## Coding Style & Naming Conventions

Follow existing R style: two-space indentation, `<-` assignment, snake_case functions and variables, and leading dots for internal helpers. Prefer explicit calls such as `stats::quantile()`. Document exported functions with roxygen comments; regenerate documentation instead of editing generated files. No formatter or linter is configured.

## Testing Guidelines

Use testthat edition 3 and `test-<component>.R` filenames. Add focused behavioral tests; no numerical coverage threshold is configured. Preserve GP conditioning, acquisition, partition, RNG-restoration, and plot-rendering checks. Use `skip_if_not_installed()` for optional dependencies and report skipped tests explicitly.

Keep training, validation, and PFI rows disjoint. PFI must explain the retained fitted models without retraining them.

## Commit & Pull Request Guidelines

No usable Git history is available in this checkout. Use short imperative subjects, for example `Add classification PFI tests`. Describe the problem, changed behavior, validation commands, and limitations in each PR. Link relevant issues, update `NEWS.md` for user-visible changes, and include before/after figures for visualization changes. Exclude build archives, check directories, and local workspace metadata.
