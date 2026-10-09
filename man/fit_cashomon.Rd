% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/fit.R; regenerate with Rscript tools/document.R.
\name{fit_cashomon}
\alias{fit_cashomon}
\alias{print.cashomon_set}
\title{Find and fit an empirical CASHomon set}
\usage{
fit_cashomon(task, candidates, train_rows, validation_rows, measure = NULL, epsilon_rel = 0.05, 
    epsilon_abs = 0, budget = min(30L, nrow(candidates$domain)), search_control = list(), 
    verify_all = FALSE, seed = 1L) 
\method{print}{cashomon_set}(x, ...) 
}
\arguments{
\item{task}{
An mlr3 TaskRegr or TaskClassif.
}

\item{candidates}{
Output of cashomon_candidates.
}

\item{train_rows, validation_rows}{
Disjoint, nonempty task row IDs.
}

\item{measure}{
Minimizing mlr3 measure; defaults to MSE or classification error.
}

\item{epsilon_rel, epsilon_abs}{
Tolerances in relative and absolute loss units.
}

\item{budget}{
Maximum evaluations during active search (verification is extra).
}

\item{search_control}{
Named list of remaining truvarimp arguments, e.g.
  kernel, beta, eta, prior_mean, cost or noise.
}

\item{verify_all}{
Evaluate every remaining candidate after active search.
}

\item{seed}{
Seed for deterministic per-candidate fits, restored on exit.
}

\item{x}{
Object to print.
}

\item{...}{
Unused.
}

}
\description{
Learners are fitted on train_rows and scored on validation_rows. Search uses
a fixed seed per candidate and no repeated evaluations. After Algorithm 1,
unevaluated members of L are fitted and verified; verify_all evaluates the
entire remaining pool. The returned models all meet the final empirical
threshold relative to the best evaluated configuration. This is not a
guarantee about population risk or unobserved candidates.
}
\value{
A cashomon_set with named fitted models, member table, full archive,
  algorithm result, threshold, task, measure and original row partitions.
}
\details{
Verification fits are additional to the search budget and are recorded in
\code{n_verification}. With partial evaluation the empirical threshold need
not equal the threshold for the entire candidate pool. Models are never
refitted on validation or explanation rows.
}
\seealso{
\code{\link{cashomon_pfi}}, \code{\link{truvarimp}}
}
