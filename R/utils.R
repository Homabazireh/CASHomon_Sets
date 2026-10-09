.need <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Install the optional dependency with install.packages(\"", package,
         "\") to use this function.", call. = FALSE)
  }
}

.number <- function(x, name, lower = -Inf, upper = Inf, integer = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      x < lower || x > upper || (integer && x != floor(x))) {
    stop(name, " must be a finite ", if (integer) "integer" else "number",
         " in [", lower, ", ", upper, "].", call. = FALSE)
  }
  invisible(x)
}

.vector <- function(x, n, name, positive = FALSE) {
  if (length(x) == 1L) x <- rep(x, n)
  if (!is.numeric(x) || length(x) != n || any(!is.finite(x)) ||
      any(if (positive) x <= 0 else x < 0)) {
    stop(name, " must have one value or one nonnegative value per candidate",
         if (positive) " (strictly positive)", ".", call. = FALSE)
  }
  x
}

.with_seed <- function(seed, code) {
  if (is.null(seed)) return(force(code))
  .number(seed, "seed", 0, .Machine$integer.max, integer = TRUE)
  existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (existed) old <- get(".Random.seed", envir = .GlobalEnv)
  on.exit(if (existed) assign(".Random.seed", old, envir = .GlobalEnv) else
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
  set.seed(seed)
  force(code)
}

.rows <- function(rows, task, name) {
  if (!is.numeric(rows) || !length(rows) || anyNA(rows) || anyDuplicated(rows) ||
      !all(rows %in% task$row_ids)) {
    stop(name, " must contain unique row IDs from the task.", call. = FALSE)
  }
  rows
}

.check_measure <- function(measure, task) {
  if (!inherits(measure, "Measure") || !isTRUE(measure$minimize) ||
      !identical(measure$task_type, task$task_type)) {
    stop("Use a minimizing loss measure compatible with the task, e.g. ",
         "regr.mse, classif.ce or classif.logloss.", call. = FALSE)
  }
}
