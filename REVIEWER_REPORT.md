# cashomon Reviewer Report

Package version: **0.1.0**  
Report date: **2026-10-09**  
Repository: [Homabazireh/CASHomon_Sets](https://github.com/Homabazireh/CASHomon_Sets)

`cashomon` searches for several models with similar validation performance and
compares their permutation feature importance (PFI). This report gives a
prospective software or methods reviewer the implementation scope, supporting
checks, unresolved validation needs, and steps for reproducing the workflow.

The numerical search has local validation evidence. The complete workflow using
`mlr3` and `xplainfi` still requires integration validation with those packages
installed. The available checks do not establish reproduction of published
experiments, comparative search efficiency, or statistical coverage guarantees.

## Purpose and scientific scope

The motivating question is whether similarly accurate models rely on different
features, including when those models belong to different model classes.
[Ewald et al. (2026), CASHomon Sets](https://arxiv.org/abs/2603.15321)
introduce this setting and TruVaRImp, an active learning method for estimating
a model set whose loss threshold depends on an unknown minimum.

This package provides a finite candidate implementation of that search, an
adapter for fitting and verifying `mlr3` models, and PFI for the retained fits.
The repository examples demonstrate the package interface; they do not
reproduce the paper's benchmark study. See [inst/CITATION](inst/CITATION) for
the package's method citation.

## Selection and explanation workflow

1. **Define candidates.** `cashomon_candidates()` expands parameter grids into
   configured learner clones. Each candidate has a model class and a stable ID.
2. **Separate data.** Training rows fit models; validation rows determine
   membership; an independent PFI holdout explains the selected models.
   The fitting and PFI functions reject overlapping partitions.
3. **Search.** `truvarimp()` uses a Gaussian process (GP) surrogate and selects
   evaluations by cost-weighted reduction in truncated uncertainty. It tracks
   `L` (classified inside), `H` (classified outside), `U` (unresolved), and `M`
   (possible minimizers).
4. **Verify membership.** `fit_cashomon()` fits any unevaluated candidates in
   `L`, or every remaining candidate when `verify_all = TRUE`. It then filters
   all evaluated candidates using the final empirical threshold.
5. **Explain retained fits.** `cashomon_pfi()` computes the loss change after
   feature permutation on the PFI holdout. Its frozen learner adapter is
   designed to reuse the retained fitted predictors when `xplainfi` invokes
   training. The adapter's integration tests remain to be executed locally.
6. **Describe variation.** Summaries average permutations within each model
   before calculating ranges, quantiles, and ranks across models. Each retained
   configuration receives equal weight.

The final empirical selection rule in [R/fit.R](R/fit.R) is:

```text
threshold = best evaluated validation loss * (1 + epsilon_rel) + epsilon_abs
retain every evaluated candidate with validation loss <= threshold
```

With `verify_all = TRUE`, this determines membership for the entire finite pool
under the chosen split and per-candidate seed. With `verify_all = FALSE`, a
better or qualifying unevaluated candidate can remain undiscovered. The
surrogate sets in `search` and the verified `members` table therefore have
different meanings. Verification fits are additional to the active search
`budget` and are counted in `n_verification`.

## Implementation map

| Component | Source | Main review concern |
|---|---|---|
| Candidate grids | [R/candidates.R](R/candidates.R) | Parameter validation, learner cloning, and heterogeneous model classes |
| GP covariance | [R/kernel.R](R/kernel.R) | Numeric scaling, categorical and inactive parameters, independent class blocks |
| Active search | [R/truvarimp.R](R/truvarimp.R) | Posterior updates, acquisition, threshold bounds, partitions, and stopping |
| Model fitting | [R/fit.R](R/fit.R) | Row separation, final membership, cached fits, and evaluation accounting |
| PFI and summaries | [R/pfi.R](R/pfi.R) | Frozen predictor behavior, baseline loss agreement, score schema, and repeat counts |
| Visualizations | [R/plots.R](R/plots.R) | Model variation versus permutation variation and preservation of negative PFI |
| Shared validation | [R/utils.R](R/utils.R) | Input checks and restoration of the caller's random number generator state |

Public interfaces are documented in [man/](man/) and illustrated in the
[vignette](vignettes/cashomon.Rmd). Reference documentation and `NAMESPACE`
are generated from comments in `R/`; regenerate them with
[tools/document.R](tools/document.R).

## Validation evidence

The [validation record](VALIDATION.md) describes earlier local checks on
2026-10-09 using R 4.5.1 on Ubuntu 20.04. Its restricted package check result
must be read together with the exclusions below.

| Check | Evidence and scope |
|---|---|
| Package build, installation, and loading | Previously recorded as successful. |
| Restricted package check | Previously recorded as `Status: OK`, with tests and vignette checks disabled and optional dependencies not required. This is not a full integration result. |
| Numerical and plotting assertions | A previous temporary base-R runner reported 10 test bodies and 54 assertions passed, with 4 integration bodies skipped. It did not run the testthat framework. |
| Additional GP audit | The earlier record reports agreement with independent batch posterior calculations for 30 random positive-definite priors, within `1e-9`. |
| Plot rendering | All four PFI views previously rendered to PDF using ggplot2 3.5.1 and constructed fixtures. Those figures are not fitted-model PFI results. |
| Vignette | Knitr previously processed the numerical example into Markdown; optional ML sections skipped. HTML rendering remained untested without Pandoc. |
| Documentation generation | The existing help files were initially generated by an offline bootstrap. Standard roxygen2 regeneration remains to be validated. |
| Fresh syntax check for this report | All 18 R files under `R/`, `tests/`, `tools/`, and `inst/examples/` parsed successfully with R 4.5.1. |
| Fresh numerical smoke check | The known six-candidate example returned `L = 1:3`, `H = 4:6`, no unresolved candidates, and stopping reason `classified`. |

The active R library checked for this report cannot load `testthat`, `mlr3`,
`xplainfi`, `ggplot2`, `roxygen2`, `knitr`, `rmarkdown`, `ranger`, or `R6`.
`rpart` is available; Pandoc is absent from `PATH`. The earlier validation used
a temporary library assembled from cached packages, so its available tooling
differs from the current default library.

The full testthat suite and both fitted-model examples have no successful
local execution recorded. No measured prediction scores, PFI values, or
runtime comparisons are claimed here. The
[GitHub Actions workflow](.github/workflows/R-CMD-check.yaml) is configured to
install dependencies and Pandoc, regenerate documentation, check the package,
and run the regression example. Configuration alone is not evidence of a
successful CI run; verify the run for the commit under review.

## Tests to inspect

| Test file | Behavioral coverage |
|---|---|
| [test-truvarimp.R](tests/testthat/test-truvarimp.R) | Sequential versus batch GP conditioning; acquisition costs and relative scaling; known level sets; partition invariants; repeated noisy queries; RNG restoration; invalid inputs |
| [test-kernel.R](tests/testthat/test-kernel.R) | Class independence, positive semidefiniteness, and categorical or inactive parameters |
| [test-fit.R](tests/testthat/test-fit.R) | Verified membership and accounting for search and verification fits |
| [test-pfi.R](tests/testthat/test-pfi.R) | Retention of fitted models; prevention of retraining; repeatability; holdout separation; classification probabilities and non-contiguous row IDs; summaries |
| [test-plots.R](tests/testthat/test-plots.R) | Building and rendering all four PFI views and building the search progress plot |

Tests use explicit skips for optional dependencies. A passing run with skipped
ML tests does not validate fitting or PFI. The regression fitting fixture uses
a generous absolute tolerance to retain all four candidate trees; it checks
accounting and model preservation, rather than narrow-threshold selection
quality. Additional integration cases with both retained and rejected
candidates would strengthen that evidence.

## Limitations and interpretation

- **Search assumptions.** The covariance matrix is fixed during search.
  Default confidence multipliers are practical choices, without automatic
  calibration of theoretical coverage. `L` and `H` assignments are permanent;
  confidence bounds are not intersected across iterations.
- **Finite search space.** Candidate classes, grids, scaling, and tolerances
  determine which alternatives can be found. Results do not cover every
  possible model or hyperparameter value. Equal weighting of configurations
  also means that denser grids can change the reported distributions.
- **Empirical performance.** Membership uses a chosen validation split.
  Similar validation loss does not establish equivalent population risk.
  Preprocessing must be fitted using training rows only.
- **PFI interpretation.** Marginal permutation can create unusual feature
  combinations when predictors are correlated. Negative importance is
  retained. Permutation percentiles describe shuffle variation conditional on
  the fitted model and holdout; model ranges describe the retained set.
  Neither is a population confidence interval or a causal effect.
- **Computational cost.** For `C` candidates, dense covariance storage is
  `O(C^2)`, covariance validation is `O(C^3)`, and each acquisition step is
  `O(C^2)`, excluding model fitting. Full verification evaluates the entire
  pool and therefore cannot itself demonstrate savings in fitting cost.
- **Integration compatibility.** The PFI adapter checks baseline loss
  agreement, expected score columns, finite values, and repeat counts.
  Those runtime checks still need validation against installed `mlr3` and
  `xplainfi` versions. Baseline loss equality alone does not establish equality
  of every individual prediction.

## Reproduce the full workflow

Use R 4.1 or newer and install Pandoc for vignette rendering. From the
repository root, install the optional workflow and development dependencies
listed in [DESCRIPTION](DESCRIPTION), respecting its minimum versions:

```r
install.packages(c(
  "ggplot2", "mlr3", "xplainfi", "R6", "mlr3learners", "ranger", "rpart",
  "testthat", "knitr", "rmarkdown", "roxygen2"
))
```

Then run in a terminal, stopping to investigate any failure:

```sh
Rscript tools/document.R
Rscript -e 'testthat::test_local()'
R CMD build .
R CMD check cashomon_0.1.0.tar.gz --no-manual
R CMD INSTALL cashomon_0.1.0.tar.gz
Rscript inst/examples/workflow.R
Rscript inst/examples/classification.R
Rscript -e 'library(cashomon); library(mlr3); library(xplainfi); library(ggplot2); sessionInfo()'
```

Match the archive name to the version in `DESCRIPTION`. Retain the commit ID,
`sessionInfo()` output, test summary including skips, and package check log
with the review evidence. Inspect any documentation changes after regeneration.

The [regression example](inst/examples/workflow.R) constructs 700 synthetic
observations, split into 350 training, 175 validation, and 175 PFI rows. Its
pool has 16 configurations: one linear model, six trees, and nine random
forests. Active search has a budget of 10 evaluations and full verification
then evaluates all remaining configurations. It is designed to export:

- `artifacts/candidates.csv`: losses, search status, and verified membership.
- `artifacts/pfi-by-model.csv`: per-model feature means and permutation spread.
- `artifacts/pfi-permutations.csv`: individual permutation scores.
- `artifacts/workflow.rds`: fitted model and PFI objects.
- `artifacts/pfi-{cloud,heatmap,ranks,performance}.{png,pdf}` and
  `artifacts/search.png`: explanation and search plots.

The [classification example](inst/examples/classification.R) uses stratified
partitions of `iris`, probability predictions, and log loss. It produces a
cloud plot but does not explicitly export an artifact bundle.

## Priorities for reviewer assessment

1. Compare the search equations, acquisition, threshold updates, and stopping
   rules with Algorithm 1 of the cited paper, including the fixed-prior and
   confidence-calibration choices.
2. Run the full suite with all dependencies present. Confirm the frozen
   adapter preserves predictions and that the integration tests execute.
3. Audit `members` against the full evaluated archive, check disjoint row
   partitions, and reconcile active search and verification counts.
4. Reproduce both examples and inspect the exported regression results before
   drawing conclusions about feature reliance or model variation.
5. For claims about search efficiency or scientific robustness, add comparisons
   against exhaustive evaluation and sensitivity analyses over grids, splits,
   tolerances, seeds, and GP settings.

Before a release, replace the placeholder maintainer identity in
`DESCRIPTION`, regenerate documentation with roxygen2, and attach a full
package check and CI result for the reviewed commit.
