% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/pfi.R; regenerate with Rscript tools/document.R.
\name{summarise_cashomon_pfi}
\alias{summarise_cashomon_pfi}
\title{Summarize variation across fitted models}
\usage{
summarise_cashomon_pfi(object, by_class = FALSE) 
}
\arguments{
\item{object}{
A cashomon_pfi object.
}

\item{by_class}{
Summarize model classes separately.
}

}
\description{
Describes empirical feature-importance ranges after averaging each model's
permutations. Each fitted model receives equal weight.
}
\value{
Data frame of empirical model minima, maxima, median and 5/95 percentiles.
  These are descriptive finite-set summaries, not population confidence bounds.
}
