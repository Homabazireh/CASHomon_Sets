% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/candidates.R; regenerate with Rscript tools/document.R.
\name{cashomon_candidates}
\alias{cashomon_candidates}
\title{Create a finite pool of mlr3 learner configurations}
\usage{
cashomon_candidates(learners, grids = list()) 
}
\arguments{
\item{learners}{
Named list of untrained mlr3 Learners, one per model class.
}

\item{grids}{
Named list of data frames (rows are configurations), or named
  lists of parameter vectors expanded with expand.grid. Omitted classes use
  the learner's current parameters as a single configuration.
}

}
\description{
Expands parameter grids into configured learner clones for multiple model
classes, retaining the learner's current settings when a grid is omitted.
}
\value{
A cashomon_candidates object containing configured learner clones,
  candidate IDs and a domain suitable for the GP kernel.
}
\seealso{
\code{\link{fit_cashomon}}
}
