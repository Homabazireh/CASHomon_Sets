# Validation record

Validated locally on 2026-10-09 with R 4.5.1 on Ubuntu 20.04.

## Package layout update

The package now has a flat `R/` directory, generated reference documentation,
`tests/testthat.R`, component tests under `tests/testthat/`, a getting-started
vignette and `NEWS.md`.

- The updated package builds, installs and loads successfully.
- Restricted package checks report **Status: OK**, with the testthat runner
  and vignette build explicitly disabled because their tooling is unavailable.
  Syntax, static code analysis, help pages, namespace, documentation consistency
  and runnable help examples pass.
- All 16 R source, test and development-script files parse successfully.
- A temporary base-R assertion runner executed the migrated test bodies:
  **10 test bodies passed, 54 assertions passed, 4 integration bodies skipped**.
  This validates the available numerical and plotting checks but is not an
  execution of the testthat framework itself.
- All four PFI visualization types render to PDF using ggplot2 3.5.1.
  Their tests use explicitly constructed fixtures, not experimental PFI results.
- Knitr successfully processes the vignette into Markdown, including its
  numerical example. The optional ML sections skip because their packages are
  absent; HTML rendering was not run because Pandoc is unavailable.
- `NAMESPACE` and the nine `man/` topics were generated from source roxygen
  comments with a one-time offline bootstrap. Their headers record that origin.
  `Rscript tools/document.R` hands these files over to roxygen2 for subsequent
  regeneration. Roxygen2 itself could not be run locally.

The earlier package version, before the testthat migration, also passed its
base-R numerical tests and an additional audit of 30 randomly generated
positive-definite GP priors against independent batch posterior calculations
within 1e-9. No numerical implementation was changed in the layout update.

## Executed supplemental results

`inst/examples/offline-workflow.R` was executed using the cached R packages.
Its outputs are in `artifacts/direct-r-demo/`: 16 evaluated configurations,
12 retained fitted models across three classes, 48 model-feature mean PFI
values, 1,440 permutation scores, and six figures in both PNG and PDF.

This is a direct-R implementation of loss-difference PFI on simulated data;
it does not execute or validate xplainfi. The 350 training, 175 validation and
175 explanation rows are disjoint. TruVaRImp chose 10 evaluations, followed
by 6 extra fits to verify the entire finite candidate pool.

The script checks membership, score aggregation, complete model coverage,
unchanged fitted models, and the PFI loss-difference identity. An independent
linear-model algebra check validates its permutation scores to 1e-10.
Figures were rendered and visually inspected. CSV exports include the full
data, predictions and permutation plan, with seeds, package versions and file
checksums for reproduction. The local model RDS is excluded from Git.

## Remaining validation

`mlr3`, `xplainfi`, `mlr3learners`, `testthat` and `roxygen2` are unavailable
locally, and package downloads are blocked. Pandoc is also absent.

The actual mlr3 model-selection workflow, xplainfi PFI calculations, and
regression/classification integration tests have not been executed here.
The supplemental direct-R figures do not remove this xplainfi integration gap.

GitHub Actions is configured to install dependencies and Pandoc, regenerate
documentation with roxygen2, run full package checks with testthat and vignettes,
and execute the regression example. That workflow has not been run remotely.

## Reproduce with full dependencies

From the repository root:

```sh
Rscript tools/document.R
R CMD build .
R CMD check cashomon_0.1.0.tar.gz --no-manual
R CMD INSTALL cashomon_0.1.0.tar.gz
Rscript inst/examples/workflow.R
Rscript inst/examples/classification.R
```

The local restricted checks used a temporary library assembled from the user's
existing package cache without modifying that cache:

```sh
R_LIBS=/tmp/cashomon-r-lib /usr/lib/R/bin/R CMD build --no-build-vignettes .
R_LIBS=/tmp/cashomon-r-lib _R_CHECK_FORCE_SUGGESTS_=false \
  /usr/lib/R/bin/R CMD check cashomon_0.1.0.tar.gz \
  --no-manual --no-tests --ignore-vignettes
```

The local check log is `cashomon.Rcheck/00check.log`. Its successful status
does not establish that skipped tooling or ML integration works end to end.
