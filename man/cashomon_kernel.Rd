% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/kernel.R; regenerate with Rscript tools/document.R.
\name{cashomon_kernel}
\alias{cashomon_kernel}
\title{Kernel on a finite, possibly hierarchical candidate domain}
\usage{
cashomon_kernel(domain, class_col = "model_class", lengthscale = 1, variance = 1) 
}
\arguments{
\item{domain}{
Nonempty data frame of configurations.
}

\item{class_col}{
Column identifying model classes, or NULL.
}

\item{lengthscale}{
Positive RBF length scale in encoded coordinates.
}

\item{variance}{
Positive marginal prior variance.
}

}
\description{
Numeric columns are range-scaled, categorical columns are one-hot encoded,
and missing/inactive parameters get an explicit activity indicator. Independent
model classes have zero covariance. The kernel is fixed throughout search.
}
\value{
A symmetric positive semidefinite covariance matrix.
}
\examples{
cashomon_kernel(data.frame(x = c(1, 2, 3)), class_col = NULL)
}
