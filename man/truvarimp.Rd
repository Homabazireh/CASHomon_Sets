% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/truvarimp.R; regenerate with Rscript tools/document.R.
\name{truvarimp}
\alias{truvarimp}
\alias{print.truvarimp_result}
\title{Finite-domain TruVaRImp (Algorithm 1)}
\usage{
truvarimp(domain, objective, kernel = NULL, epsilon_rel = 0.05, epsilon_abs = 0, 
    budget = nrow(domain), noise = 1e-06, cost = 1, beta = 4, eta = 1, r = 0.5, delta = 0.1, 
    prior_mean = 0, allow_repeats = TRUE, seed = NULL) 
\method{print}{truvarimp_result}(x, ...) 
}
\arguments{
\item{domain}{
Nonempty data frame; rows are candidate configurations.
}

\item{objective}{
Function taking a one-row data frame and returning one loss.
}

\item{kernel}{
Prior covariance matrix; defaults to cashomon_kernel(domain).
}

\item{epsilon_rel, epsilon_abs}{
Nonnegative near-optimality tolerances.
  Relative tolerances assume nonnegative latent losses; noisy observations
  may be negative.
}

\item{budget}{
Maximum number of objective evaluations.
}

\item{noise}{
Observation noise VARIANCE, scalar or one value per candidate.
}

\item{cost}{
Positive evaluation cost, scalar or one value per candidate.
}

\item{beta}{
Positive scalar or function of epoch giving squared CI multiplier.
}

\item{eta}{
Initial positive truncation width, in objective units.
}

\item{r}{
Epoch shrink factor strictly between zero and one.
}

\item{delta}{
Positive epoch slack.
}

\item{prior_mean}{
Scalar or one finite value per candidate.
}

\item{allow_repeats}{
Whether to allow repeated noisy evaluations (paper default).
}

\item{seed}{
Optional local random seed. Ties use candidate row order.
}

\item{x}{
Object to print.
}

\item{...}{
Unused.
}

}
\description{
Uses a fixed GP prior, exact rank-one posterior updates, and cost-weighted
truncated variance reduction over both U and M. Membership in L/H is permanent,
as in the paper. Bounds are not intersected across iterations. The tolerance
defines h = min(c) * (1 + epsilon_rel) + epsilon_abs.
}
\value{
A truvarimp_result with integer-index sets L/H/U/M, posterior,
  observations, trace, bounds, parameters and stopping reason.
}
\details{
The target threshold uses the unknown minimum. Confidence multipliers are
user choices, not automatic calibrations of theoretical coverage. Search
stops at the budget, a complete partition, or exhausted evaluable candidates.
}
\references{
Ewald et al. (2026), \doi{10.48550/arXiv.2603.15321}.
}
\seealso{
\code{\link{fit_cashomon}}, \code{\link{cashomon_kernel}}
}
\examples{
domain <- data.frame(x = seq(0, 1, length.out = 12))
result <- truvarimp(domain, function(row) (row$x - 0.3)^2,
  epsilon_abs = 0.05, noise = 0, budget = 8)
print(result)
}
