[1mdiff --cc README.md[m
[1mindex 73fb68e,cdf707d..0000000[m
[1m--- a/README.md[m
[1m+++ b/README.md[m
[36m@@@ -1,257 -1,1 +1,261 @@@[m
[31m -# CASHomon_Sets[m
[32m++<<<<<<< HEAD[m
[32m +# cashomon[m
[32m +[m
[32m +Find multiple well-performing models, then compare what they rely on.[m
[32m +[m
[32m +`cashomon` is an R package implementing **TruVaRImp, Algorithm 1** in[m
[32m +[Ewald et al. (2026), CASHomon Sets](https://arxiv.org/pdf/2603.15321).[m
[32m +It searches a finite pool containing different model classes and hyperparameters,[m
[32m +retains fitted models meeting an empirical loss threshold, and uses[m
[32m +[`xplainfi::PFI`](https://mlr-org.github.io/xplainfi/reference/PFI.html) to explain[m
[32m +**every retained model**. The PFI definition is the loss increase after permuting[m
[32m +a feature, following [Breiman (2001)](https://doi.org/10.1023/A:1010933404324).[m
[32m +[m
[32m +## Install[m
[32m +[m
[32m +From this directory, with R 4.1 or later:[m
[32m +[m
[32m +```r[m
[32m +install.packages(c("mlr3", "xplainfi", "R6", "ggplot2", "mlr3learners", "ranger", "rpart"))[m
[32m +install.packages(".", repos = NULL, type = "source")[m
[32m +```[m
[32m +[m
[32m +The numerical search has no external dependencies. The ML integration and plots[m
[32m +load their dependencies only when used. This lets you use `truvarimp()` with any[m
[32m +scalar objective, independently of mlr3.[m
[32m +[m
[32m +## Models to PFI in one workflow[m
[32m +[m
[32m +```r[m
[32m +library(cashomon)[m
[32m +library(mlr3)[m
[32m +[m
[32m +task <- as_task_regr(mtcars, target = "mpg")[m
[32m +set.seed(42)[m
[32m +rows <- sample(task$row_ids)[m
[32m +train <- rows[1:16][m
[32m +validation <- rows[17:24][m
[32m +test <- rows[25:32][m
[32m +[m
[32m +# mlr3 includes rpart and a featureless baseline. More learners are available[m
[32m +# through mlr3learners, as shown in the larger example linked below.[m
[32m +pool <- cashomon_candidates([m
[32m +  learners = list(Tree = lrn("regr.rpart"), Baseline = lrn("regr.featureless")),[m
[32m +  grids = list(Tree = list(cp = c(0.001, 0.01, 0.05), maxdepth = c(2L, 4L)))[m
[32m +)[m
[32m +[m
[32m +models <- fit_cashomon([m
[32m +  task, pool, train_rows = train, validation_rows = validation,[m
[32m +  epsilon_rel = 0.20, budget = 5, verify_all = TRUE[m
[32m +)[m
[32m +models$members       # loss and model class for each retained fit[m
[32m +models$models        # the actual trained mlr3 Learners[m
[32m +models$search        # Algorithm 1's L, H, U and M[m
[32m +[m
[32m +pfi <- cashomon_pfi(models, test_rows = test, n_repeats = 30)[m
[32m +pfi$importance       # one row per model and feature[m
[32m +pfi$scores           # all individual permutations[m
[32m +summarise_cashomon_pfi(pfi, by_class = TRUE)[m
[32m +[m
[32m +plot_cashomon_pfi(pfi, "cloud")[m
[32m +plot_cashomon_pfi(pfi, "heatmap")[m
[32m +plot_cashomon_pfi(pfi, "ranks")[m
[32m +plot_cashomon_pfi(pfi, "performance")[m
[32m +```[m
[32m +[m
[32m +This tiny dataset demonstrates the API. Use larger, suitably stratified or grouped[m
[32m +splits for substantive analysis. Training, validation and PFI rows must be disjoint.[m
[32m +[m
[32m +The complete [regression example](inst/examples/workflow.R) uses a linear model,[m
[32m +decision trees and random forests on a reproducible dataset with correlated[m
[32m +features. It writes model scores, PFI tables, fitted objects, and four PNG/PDF[m
[32m +visualizations into `artifacts/`:[m
[32m +[m
[32m +```sh[m
[32m +Rscript inst/examples/workflow.R[m
[32m +```[m
[32m +[m
[32m +A [classification example](inst/examples/classification.R) uses probability[m
[32m +predictions and log loss. For classification error, use `msr("classif.ce")`;[m
[32m +for log loss, configure learners with `predict_type = "prob"`.[m
[32m +[m
[32m +## Reading the visualizations[m
[32m +[m
[32m +| View | What it reveals |[m
[32m +|---|---|[m
[32m +| `cloud` | Per-model PFI points colored by class, a full model min/max band, and a median diamond. Features with wide bands receive different explanations despite similar predictive performance. |[m
[32m +| `heatmap` | Every model's feature-importance profile, grouped by class and ordered by validation loss. Diverging colors preserve negative PFI. |[m
[32m +| `ranks` | Whether models agree on the most important features. Each point is a model's rank; ties use average ranks. |[m
[32m +| `performance` | PFI versus validation loss, faceted by feature, with the selection threshold marked. |[m
[32m +[m
[32m +All return ordinary ggplot objects. For example:[m
[32m +[m
[32m +```r[m
[32m +p <- plot_cashomon_pfi(pfi, "cloud", permutation_intervals = TRUE)[m
[32m +ggplot2::ggsave("importance-cloud.pdf", p, width = 10, height = 6)[m
[32m +plot_cashomon_search(models)[m
[32m +```[m
[32m +[m
[32m +The cloud's optional thin lines show each fitted model's 5th–95th permutation[m
[32m +percentiles. They are **not confidence intervals**. Across-model summaries average[m
[32m +permutations first, so increasing the number of permutations does not give a model[m
[32m +more weight. The range is over the retained finite set; it is not a certified bound[m
[32m +over every possible model. Candidate counts and proposal choices affect these[m
[32m +descriptive distributions. PFI is marginal: correlated features can substitute[m
[32m +for one another, and permutation can create unusual feature combinations.[m
[32m +[m
[32m +## Search and membership[m
[32m +[m
[32m +The implemented selection rule is[m
[32m +[m
[32m +```text[m
[32m +threshold = best evaluated validation loss * (1 + epsilon_rel) + epsilon_abs[m
[32m +```[m
[32m +[m
[32m +`truvarimp()` tracks the paper's four sets: `L` (predicted inside), `H`[m
[32m +(predicted outside), `U` (unresolved), and `M` (possible minimizers). It stores[m
[32m +the posterior, threshold bounds, queried points and an iteration trace.[m
[32m +`budget` counts objective evaluations, while `cost` weights the acquisition.[m
[32m +The numerical implementation follows the GP equations and acquisition in[m
[32m +Algorithm 1; it is not exhaustive tuning followed by filtering.[m
[32m +[m
[32m +`fit_cashomon()` uses the same training and validation rows for all candidates.[m
[32m +It then fits any still-unfitted members of `L`, recomputes the threshold using[m
[32m +**all evaluated candidates**, and returns every evaluated model satisfying it.[m
[32m +The verified members and the original surrogate partition are both preserved.[m
[32m +Verification fits are additional to `budget` and counted in `n_verification`.[m
[32m +If `verify_all = TRUE`, it evaluates the entire remaining pool, giving exact[m
[32m +empirical membership for that finite pool. This is useful for small examples and[m
[32m +audits, but incurs the cost of fitting every candidate.[m
[32m +[m
[32m +With `verify_all = FALSE`, the reference is the best **evaluated** candidate;[m
[32m +unobserved configurations may be better or may be missing from the returned set.[m
[32m +Validation performance is an estimate, not a guarantee of population performance.[m
[32m +The PFI holdout never influences membership. Selected models are not retrained[m
[32m +on validation or PFI rows: a frozen mlr3 adapter ensures xplainfi explains the[m
[32m +same fitted predictors that passed selection.[m
[32m +[m
[32m +## Numerical choices and scope[m
[32m +[m
[32m +- The core uses a fixed positive semidefinite GP covariance matrix and exact[m
[32m +  sequential Gaussian conditioning. Observation `noise` means **variance**.[m
[32m +  Its acquisition accounts for both `U` and `M`, relative-tolerance scaling,[m
[32m +  epoch truncation and evaluation costs. Already evaluated points remain[m
[32m +  eligible for repeated noisy observations in the standalone algorithm.[m
[32m +- The supplied RBF kernel uses independent blocks for model classes, scaled[m
[32m +  numeric parameters, categorical indicators and explicit missingness/activity[m
[32m +  encoding. Hyperparameter coordinates should have meaningful scales; provide[m
[32m +  your own kernel for log-scaled or more specialized spaces.[m
[32m +- The fitted-model wrapper evaluates a reproducible, fixed fit per candidate,[m
[32m +  so it disables repeated evaluations and defaults to zero observation noise.[m
[32m +  Its GP scale is initialized from training-target variance for regression,[m
[32m +  and one for classification. Tune the prior for other loss scales through[m
[32m +  `search_control = list(kernel = ..., prior_mean = ..., eta = ..., beta = ...)`.[m
[32m +- Unlike the paper's experimental implementation, this package does not learn[m
[32m +  kernel hyperparameters during search. Default confidence multipliers are[m
[32m +  practical settings, not a calibration of the paper's theoretical guarantee.[m
[32m +- Search can stop early when all candidates are classified or no additional[m
[32m +  evaluations are possible. The epoch loop guards against the zero-variance[m
[32m +  degenerate case. Bounds are not intersected across iterations.[m
[32m +- The dense covariance uses O(C²) memory and acquisition costs O(C²) per step,[m
[32m +  where C is the candidate count. The initial PSD validation is O(C³). Start[m
[32m +  with hundreds of configurations; this implementation is not intended for[m
[32m +  million-candidate search spaces.[m
[32m +- Training errors stop with the candidate ID. They are not converted to[m
[32m +  arbitrary large GP losses. Learner preprocessing should be contained in the[m
[32m +  learner/pipeline and fitted on training rows only.[m
[32m +[m
[32m +## Development and verification[m
[32m +[m
[32m +The repository follows a standard R package layout:[m
[32m +[m
[32m +```text[m
[32m +CASHomon_Sets/[m
[32m +├── DESCRIPTION[m
[32m +├── NAMESPACE                 # generated from R/ documentation[m
[32m +├── R/                        # flat, grouped by component[m
[32m +│   ├── cashomon-package.R[m
[32m +│   ├── candidates.R[m
[32m +│   ├── fit.R[m
[32m +│   ├── kernel.R[m
[32m +│   ├── pfi.R[m
[32m +│   ├── plots.R[m
[32m +│   ├── truvarimp.R[m
[32m +│   └── utils.R[m
[32m +├── man/                      # generated reference documentation[m
[32m +├── tests/[m
[32m +│   ├── testthat.R[m
[32m +│   └── testthat/[m
[32m +│       ├── helper-fixtures.R[m
[32m +│       ├── test-fit.R[m
[32m +│       ├── test-kernel.R[m
[32m +│       ├── test-pfi.R[m
[32m +│       ├── test-plots.R[m
[32m +│       └── test-truvarimp.R[m
[32m +├── vignettes/[m
[32m +│   └── cashomon.Rmd[m
[32m +├── inst/examples/[m
[32m +├── tools/document.R[m
[32m +├── NEWS.md[m
[32m +├── README.md[m
[32m +└── LICENSE[m
[32m +```[m
[32m +[m
[32m +Edit documentation beside the functions in `R/`; `NAMESPACE` and `man/` are[m
[32m +generated outputs. Install the development dependencies and regenerate with:[m
[32m +[m
[32m +```r[m
[32m +install.packages(c("roxygen2", "testthat", "knitr", "rmarkdown"))[m
[32m +```[m
[32m +[m
[32m +```sh[m
[32m +Rscript tools/document.R[m
[32m +R CMD build .[m
[32m +R CMD check cashomon_0.1.0.tar.gz --no-manual[m
[32m +```[m
[32m +[m
[32m +Run the testthat edition 3 suite during development with[m
[32m +`testthat::test_local()`. Search and kernel tests compare the posterior with an[m
[32m +independent batch solve and check acquisition, exact level sets, repeated noisy[m
[32m +queries, inputs and RNG preservation. Plot tests render all four views. Fitting[m
[32m +and PFI tests cover regression, classification, data separation, repeatability[m
[32m +and preservation of the fitted model, using explicit testthat skips for missing[m
[32m +optional dependencies.[m
[32m +[m
[32m +The [getting-started vignette](vignettes/cashomon.Rmd) walks through search,[m
[32m +selection, PFI and the four plots. Building its HTML requires Pandoc, available[m
[32m +with RStudio or as a separate installation. After installing a package built[m
[32m +with vignettes, open it using `vignette("cashomon", package = "cashomon")`.[m
[32m +[m
[32m +The GitHub Actions workflow installs all dependencies, runs package checks and[m
[32m +the full regression example, and saves the resulting artifacts. Before public[m
[32m +distribution, replace the placeholder maintainer in `DESCRIPTION`.[m
[32m +[m
[32m +The local implementation and validation record is in[m
[32m +[VALIDATION.md](VALIDATION.md).[m
[32m +[m
[32m +## Upload to GitHub[m
[32m +[m
[32m +The GitHub repository is[m
[32m +[Homabazireh/CASHomon_Sets](https://github.com/Homabazireh/CASHomon_Sets).[m
[32m +For the first upload, run these commands from this package directory in a[m
[32m +terminal with write access to `.git/` and GitHub authentication configured:[m
[32m +[m
[32m +```sh[m
[32m +git init[m
[32m +git symbolic-ref HEAD refs/heads/main[m
[32m +git add .[m
[32m +git commit -m "Initial cashomon R package"[m
[32m +git remote add origin https://github.com/Homabazireh/CASHomon_Sets.git[m
[32m +git push -u origin main[m
[32m +```[m
[32m +[m
[32m +The first two commands replace `git init -b main` for older Git versions,[m
[32m +including Git 2.25.1. Commit the package source, including `NAMESPACE` and[m
[32m +`man/`. Build archives, check directories and local[m
[32m +workspace metadata are excluded by `.gitignore`. See[m
[32m +[GitHub's import instructions](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)[m
[32m +for authentication and existing-repository cases.[m
[32m++=======[m
[32m++# CASHomon_Sets[m
[32m++>>>>>>> origin/main[m
