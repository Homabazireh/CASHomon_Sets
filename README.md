# cashomon

Find multiple well-performing models, then compare what they rely on.

`cashomon` is an R package implementing **TruVaRImp, Algorithm 1** in
[Ewald et al. (2026), CASHomon Sets](https://arxiv.org/pdf/2603.15321).
It searches a finite pool containing different model classes and hyperparameters,
retains fitted models meeting an empirical loss threshold, and uses
[`xplainfi::PFI`](https://mlr-org.github.io/xplainfi/reference/PFI.html) to explain
**every retained model**. The PFI definition is the loss increase after permuting
a feature, following [Breiman (2001)](https://doi.org/10.1023/A:1010933404324).

## Install

From this directory, with R 4.1 or later:

```r
install.packages(c("mlr3", "xplainfi", "R6", "ggplot2", "mlr3learners", "ranger", "rpart"))
install.packages(".", repos = NULL, type = "source")
```

The numerical search has no external dependencies. The ML integration and plots
load their dependencies only when used. This lets you use `truvarimp()` with any
scalar objective, independently of mlr3.

## Models to PFI in one workflow

```r
library(cashomon)
library(mlr3)

task <- as_task_regr(mtcars, target = "mpg")
set.seed(42)
rows <- sample(task$row_ids)
train <- rows[1:16]
validation <- rows[17:24]
test <- rows[25:32]

# mlr3 includes rpart and a featureless baseline. More learners are available
# through mlr3learners, as shown in the larger example linked below.
pool <- cashomon_candidates(
  learners = list(Tree = lrn("regr.rpart"), Baseline = lrn("regr.featureless")),
  grids = list(Tree = list(cp = c(0.001, 0.01, 0.05), maxdepth = c(2L, 4L)))
)

models <- fit_cashomon(
  task, pool, train_rows = train, validation_rows = validation,
  epsilon_rel = 0.20, budget = 5, verify_all = TRUE
)
models$members       # loss and model class for each retained fit
models$models        # the actual trained mlr3 Learners
models$search        # Algorithm 1's L, H, U and M

pfi <- cashomon_pfi(models, test_rows = test, n_repeats = 30)
pfi$importance       # one row per model and feature
pfi$scores           # all individual permutations
summarise_cashomon_pfi(pfi, by_class = TRUE)

plot_cashomon_pfi(pfi, "cloud")
plot_cashomon_pfi(pfi, "heatmap")
plot_cashomon_pfi(pfi, "ranks")
plot_cashomon_pfi(pfi, "performance")
```

This tiny dataset demonstrates the API. Use larger, suitably stratified or grouped
splits for substantive analysis. Training, validation and PFI rows must be disjoint.

The complete [regression example](inst/examples/workflow.R) uses a linear model,
decision trees and random forests on a reproducible dataset with correlated
features. It writes model scores, PFI tables, fitted objects, and four PNG/PDF
visualizations into `artifacts/`:

```sh
Rscript inst/examples/workflow.R
```

A [classification example](inst/examples/classification.R) uses probability
predictions and log loss. For classification error, use `msr("classif.ce")`;
for log loss, configure learners with `predict_type = "prob"`.

## Reading the visualizations

| View | What it reveals |
|---|---|
| `cloud` | Per-model PFI points colored by class, a full model min/max band, and a median diamond. Features with wide bands receive different explanations despite similar predictive performance. |
| `heatmap` | Every model's feature-importance profile, grouped by class and ordered by validation loss. Diverging colors preserve negative PFI. |
| `ranks` | Whether models agree on the most important features. Each point is a model's rank; ties use average ranks. |
| `performance` | PFI versus validation loss, faceted by feature, with the selection threshold marked. |

All return ordinary ggplot objects. For example:

```r
p <- plot_cashomon_pfi(pfi, "cloud", permutation_intervals = TRUE)
ggplot2::ggsave("importance-cloud.pdf", p, width = 10, height = 6)
plot_cashomon_search(models)
```

The cloud's optional thin lines show each fitted model's 5th–95th permutation
percentiles. They are **not confidence intervals**. Across-model summaries average
permutations first, so increasing the number of permutations does not give a model
more weight. The range is over the retained finite set; it is not a certified bound
over every possible model. Candidate counts and proposal choices affect these
descriptive distributions. PFI is marginal: correlated features can substitute
for one another, and permutation can create unusual feature combinations.

## Search and membership

The implemented selection rule is

```text
threshold = best evaluated validation loss * (1 + epsilon_rel) + epsilon_abs
```

`truvarimp()` tracks the paper's four sets: `L` (predicted inside), `H`
(predicted outside), `U` (unresolved), and `M` (possible minimizers). It stores
the posterior, threshold bounds, queried points and an iteration trace.
`budget` counts objective evaluations, while `cost` weights the acquisition.
The numerical implementation follows the GP equations and acquisition in
Algorithm 1; it is not exhaustive tuning followed by filtering.

`fit_cashomon()` uses the same training and validation rows for all candidates.
It then fits any still-unfitted members of `L`, recomputes the threshold using
**all evaluated candidates**, and returns every evaluated model satisfying it.
The verified members and the original surrogate partition are both preserved.
Verification fits are additional to `budget` and counted in `n_verification`.
If `verify_all = TRUE`, it evaluates the entire remaining pool, giving exact
empirical membership for that finite pool. This is useful for small examples and
audits, but incurs the cost of fitting every candidate.

With `verify_all = FALSE`, the reference is the best **evaluated** candidate;
unobserved configurations may be better or may be missing from the returned set.
Validation performance is an estimate, not a guarantee of population performance.
The PFI holdout never influences membership. Selected models are not retrained
on validation or PFI rows: a frozen mlr3 adapter ensures xplainfi explains the
same fitted predictors that passed selection.

## Numerical choices and scope

- The core uses a fixed positive semidefinite GP covariance matrix and exact
  sequential Gaussian conditioning. Observation `noise` means **variance**.
  Its acquisition accounts for both `U` and `M`, relative-tolerance scaling,
  epoch truncation and evaluation costs. Already evaluated points remain
  eligible for repeated noisy observations in the standalone algorithm.
- The supplied RBF kernel uses independent blocks for model classes, scaled
  numeric parameters, categorical indicators and explicit missingness/activity
  encoding. Hyperparameter coordinates should have meaningful scales; provide
  your own kernel for log-scaled or more specialized spaces.
- The fitted-model wrapper evaluates a reproducible, fixed fit per candidate,
  so it disables repeated evaluations and defaults to zero observation noise.
  Its GP scale is initialized from training-target variance for regression,
  and one for classification. Tune the prior for other loss scales through
  `search_control = list(kernel = ..., prior_mean = ..., eta = ..., beta = ...)`.
- Unlike the paper's experimental implementation, this package does not learn
  kernel hyperparameters during search. Default confidence multipliers are
  practical settings, not a calibration of the paper's theoretical guarantee.
- Search can stop early when all candidates are classified or no additional
  evaluations are possible. The epoch loop guards against the zero-variance
  degenerate case. Bounds are not intersected across iterations.
- The dense covariance uses O(C²) memory and acquisition costs O(C²) per step,
  where C is the candidate count. The initial PSD validation is O(C³). Start
  with hundreds of configurations; this implementation is not intended for
  million-candidate search spaces.
- Training errors stop with the candidate ID. They are not converted to
  arbitrary large GP losses. Learner preprocessing should be contained in the
  learner/pipeline and fitted on training rows only.

## Development and verification

The repository follows a standard R package layout:

```text
CASHomon_Sets/
├── DESCRIPTION
├── NAMESPACE                 # generated from R/ documentation
├── R/                        # flat, grouped by component
│   ├── cashomon-package.R
│   ├── candidates.R
│   ├── fit.R
│   ├── kernel.R
│   ├── pfi.R
│   ├── plots.R
│   ├── truvarimp.R
│   └── utils.R
├── man/                      # generated reference documentation
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── helper-fixtures.R
│       ├── test-fit.R
│       ├── test-kernel.R
│       ├── test-pfi.R
│       ├── test-plots.R
│       └── test-truvarimp.R
├── vignettes/
│   └── cashomon.Rmd
├── inst/examples/
├── tools/document.R
├── NEWS.md
├── README.md
└── LICENSE
```

Edit documentation beside the functions in `R/`; `NAMESPACE` and `man/` are
generated outputs. Install the development dependencies and regenerate with:

```r
install.packages(c("roxygen2", "testthat", "knitr", "rmarkdown"))
```

```sh
Rscript tools/document.R
R CMD build .
R CMD check cashomon_0.1.0.tar.gz --no-manual
```

Run the testthat edition 3 suite during development with
`testthat::test_local()`. Search and kernel tests compare the posterior with an
independent batch solve and check acquisition, exact level sets, repeated noisy
queries, inputs and RNG preservation. Plot tests render all four views. Fitting
and PFI tests cover regression, classification, data separation, repeatability
and preservation of the fitted model, using explicit testthat skips for missing
optional dependencies.

The [getting-started vignette](vignettes/cashomon.Rmd) walks through search,
selection, PFI and the four plots. Building its HTML requires Pandoc, available
with RStudio or as a separate installation. After installing a package built
with vignettes, open it using `vignette("cashomon", package = "cashomon")`.

The GitHub Actions workflow installs all dependencies, runs package checks and
the full regression example, and saves the resulting artifacts. Before public
distribution, replace the placeholder maintainer in `DESCRIPTION`.

The local implementation and validation record is in
[VALIDATION.md](VALIDATION.md). Prospective reviewers can start with
[REVIEWER_REPORT.md](REVIEWER_REPORT.md) for the implementation scope,
validation evidence, limitations, and reproduction steps.

## Upload to GitHub

The GitHub repository is
[Homabazireh/CASHomon_Sets](https://github.com/Homabazireh/CASHomon_Sets).
To upload new or changed files from an existing checkout, run these commands
one at a time from the package directory in a terminal with write access to
`.git/` and GitHub authentication configured:

```sh
git status
git add .
git commit -m "Add new files"
git pull --rebase origin main
git push -u origin main
```

Before staging, inspect `git status` and finish any pending merge or rebase.
If there are no new changes to commit, skip `git add` and `git commit`.
If a command reports a conflict or error, resolve it before continuing.
Commit package source, including `NAMESPACE` and `man/`; `.gitignore` excludes
build archives, check directories, and local workspace metadata.

After a successful push, open
[the reviewer report on GitHub](https://github.com/Homabazireh/CASHomon_Sets/blob/main/REVIEWER_REPORT.md)
to confirm it is available on `main`.
