% Generated from R/ roxygen comments by the offline documentation bootstrap.
% Edit documentation in R/plots.R; regenerate with Rscript tools/document.R.
\name{plot_cashomon_pfi}
\alias{plot_cashomon_pfi}
\title{Visualize feature importance across the CASHomon set}
\usage{
plot_cashomon_pfi(object, type = c("cloud", "heatmap", "ranks", "performance"), features = NULL, 
    permutation_intervals = FALSE) 
}
\arguments{
\item{object}{
Output of cashomon_pfi.
}

\item{type}{
One of cloud, heatmap, ranks or performance.
}

\item{features}{
Optional subset of features to display. Ranks remain ranks
  within the full set of features computed by cashomon_pfi.
}

\item{permutation_intervals}{
Show within-model permutation spread in cloud.
}

}
\description{
All views give each fitted configuration one observation, averaging its
permutations first. The cloud shows per-model points, the full empirical
min/max range and median; the heatmap shows model profiles; ranks shows
within-model ranks with average ties; performance relates PFI to validation
loss. Permutation intervals, when requested, are 5/95 percentiles, not CIs.
}
\value{
A customizable ggplot object; save with ggplot2::ggsave.
}
