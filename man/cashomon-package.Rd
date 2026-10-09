% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/cashomon-package.R; regenerate with Rscript tools/document.R.
\name{cashomon-package}
\alias{cashomon}
\alias{cashomon-package}
\title{CASHomon model sets and permutation feature importance}
\description{
Search finite collections of model configurations with TruVaRImp, fit and
verify an empirical CASHomon set, and compare feature importance across its
retained models using xplainfi.
}
\docType{package}
\details{
Start with \code{\link{cashomon_candidates}} and \code{\link{fit_cashomon}},
then use \code{\link{cashomon_pfi}} and \code{\link{plot_cashomon_pfi}}.
The numerical \code{\link{truvarimp}} search also accepts arbitrary scalar
objectives without the optional machine-learning dependencies.
}
\references{
Ewald et al. (2026), \doi{10.48550/arXiv.2603.15321}.
}
\keyword{internal}
