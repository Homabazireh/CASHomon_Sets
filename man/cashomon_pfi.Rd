% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/pfi.R; regenerate with Rscript tools/document.R.
\name{cashomon_pfi}
\alias{cashomon_pfi}
\alias{print.cashomon_pfi}
\title{Permutation feature importance for every retained fitted model}
\usage{
cashomon_pfi(object, test_rows = NULL, features = NULL, n_repeats = 30L, seed = 1L, 
    keep_explainers = FALSE) 
\method{print}{cashomon_pfi}(x, ...) 
}
\arguments{
\item{object}{
A fitted cashomon_set.
}

\item{test_rows}{
Task row IDs used only for explanations, disjoint from both
  training and validation. Defaults to all unused task rows.
}

\item{features}{
Character vector of features; NULL means all task features.
}

\item{n_repeats}{
Positive number of permutations per feature and model.
}

\item{seed}{
Seed reset to the same value for each model for comparability.
}

\item{keep_explainers}{
Retain the underlying xplainfi R6 objects.
}

\item{x}{
Object to print.
}

\item{...}{
Unused.
}

}
\description{
Runs xplainfi::PFI on a shared, independent explanation holdout. A frozen
learner adapter preserves the exact selected fit even when xplainfi trains
its input learner. No new fitted predictor is substituted. All permutations
and feature means are retained; model spread and permutation spread are
reported separately. Uses loss differences (permuted minus baseline).
}
\value{
A cashomon_pfi with tidy scores and per-model importance data frames,
  model metadata, settings and optionally xplainfi objects.
}
\details{
Requires mlr3, xplainfi and R6. Permutation percentiles quantify shuffle
variation conditional on the model and holdout, not sampling confidence.
Negative PFI values are retained.
}
\seealso{
\code{\link{plot_cashomon_pfi}}, \code{\link{summarise_cashomon_pfi}}
}
