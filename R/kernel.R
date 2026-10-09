#' Kernel on a finite, possibly hierarchical candidate domain
#'
#' Numeric columns are range-scaled, categorical columns are one-hot encoded,
#' and missing/inactive parameters get an explicit activity indicator. Independent
#' model classes have zero covariance. The kernel is fixed throughout search.
#' @param domain Nonempty data frame of configurations.
#' @param class_col Column identifying model classes, or NULL.
#' @param lengthscale Positive RBF length scale in encoded coordinates.
#' @param variance Positive marginal prior variance.
#' @return A symmetric positive semidefinite covariance matrix.
#' @examples
#' cashomon_kernel(data.frame(x = c(1, 2, 3)), class_col = NULL)
#' @export
cashomon_kernel <- function(domain, class_col = "model_class",
                            lengthscale = 1, variance = 1) {
  if (!is.data.frame(domain) || nrow(domain) < 1L)
    stop("domain must be a nonempty data frame.", call. = FALSE)
  .number(lengthscale, "lengthscale", .Machine$double.eps)
  .number(variance, "variance", .Machine$double.eps)
  if (!is.null(class_col) && !(class_col %in% names(domain)))
    stop("class_col is not a column in domain; use NULL for a single class.",
         call. = FALSE)
  cls <- if (is.null(class_col)) rep("model", nrow(domain)) else domain[[class_col]]
  if (anyNA(cls)) stop("Model classes cannot be missing.", call. = FALSE)
  k <- matrix(0, nrow(domain), nrow(domain))
  for (label in unique(cls)) {
    ii <- which(cls == label)
    z <- matrix(0, length(ii), 0L)
    for (column in setdiff(names(domain), class_col)) {
      v <- domain[[column]][ii]
      if (is.list(v)) stop("Kernel columns must be atomic.", call. = FALSE)
      active <- !is.na(v)
      if (!any(active)) next
      if (is.numeric(v)) {
        if (any(!is.finite(v[active])))
          stop("Numeric kernel columns must be finite or NA.", call. = FALSE)
        span <- diff(range(v[active]))
        value <- rep(0, length(v))
        value[active] <- (v[active] - min(v[active])) / if (span > 0) span else 1
        z <- cbind(z, value, as.numeric(active))
      } else {
        for (level in unique(as.character(v[active])))
          z <- cbind(z, as.numeric(active & as.character(v) %in% level))
        z <- cbind(z, as.numeric(!active))
      }
    }
    d2 <- if (!ncol(z)) matrix(0, length(ii), length(ii)) else
      pmax(outer(rowSums(z^2), rowSums(z^2), "+") - 2 * tcrossprod(z), 0)
    k[ii, ii] <- variance * exp(-d2 / (2 * lengthscale^2))
  }
  k
}
