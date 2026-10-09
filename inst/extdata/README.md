# Raw demonstration data

`simulated-data.csv` contains all 700 observations used for the direct-R PFI
demonstration in `artifacts/direct-r-demo/`. It is synthetic data generated
within this repository, not an experimental dataset from the CASHomon paper.
It is provided under the package's MIT license.

## Columns

| Column | Meaning |
|---|---|
| `row_id` | Unique original row identifier, 1–700; not a predictor. |
| `split` | `training` (350 rows), `validation` (175), or `pfi_holdout` (175); not a predictor. |
| `signal` | Standard normal predictor. |
| `proxy` | `signal` plus independent normal noise with standard deviation 0.25. |
| `modifier` | Predictor uniformly distributed between -1 and 1. |
| `noise` | Independent standard normal predictor. |
| `target` | `3 * signal + 1.5 * modifier^2` plus independent normal noise with standard deviation 0.8. |

## Load and reproduce

```r
raw_data <- read.csv(system.file("extdata", "simulated-data.csv",
                                package = "cashomon", mustWork = TRUE))
table(raw_data$split)
```

From a checkout, use `read.csv("inst/extdata/simulated-data.csv")` instead.
There are no missing values. Training, validation, and holdout rows are disjoint.
Use `target` as the response and the four named predictors as inputs.

`inst/examples/offline-workflow.R` generates the data and split using
`set.seed(2603)`, then trains the models and exports the results. Run it from the
repository root to reproduce the demonstration, including the original sampled
row order. It also refreshes this CSV from the identical artifact copy. The
demonstration uses direct-R PFI because xplainfi was unavailable during that run.
