#' Create a finite pool of mlr3 learner configurations
#'
#' Expands parameter grids into configured learner clones for multiple model
#' classes, retaining the learner's current settings when a grid is omitted.
#'
#' @param learners Named list of untrained mlr3 Learners, one per model class.
#' @param grids Named list of data frames (rows are configurations), or named
#'   lists of parameter vectors expanded with expand.grid. Omitted classes use
#'   the learner's current parameters as a single configuration.
#' @return A cashomon_candidates object containing configured learner clones,
#'   candidate IDs and a domain suitable for the GP kernel.
#' @seealso \code{\link{fit_cashomon}}
#' @export
cashomon_candidates <- function(learners, grids = list()) {
  .need("mlr3")
  if (!is.list(learners) || !length(learners) || is.null(names(learners)) ||
      anyNA(names(learners)) || any(!nzchar(names(learners))) || anyDuplicated(names(learners)))
    stop("learners must be a nonempty, uniquely named list.", call. = FALSE)
  if (!is.list(grids) || (length(grids) &&
      (is.null(names(grids)) || anyDuplicated(names(grids)) ||
       !all(names(grids) %in% names(learners)))))
    stop("grids must be a list named by model class.", call. = FALSE)
  configured <- domains <- list()
  ids <- character()
  for (label in names(learners)) {
    learner <- learners[[label]]
    if (!inherits(learner, "Learner") || !is.null(learner$model))
      stop("Each learner must be an untrained mlr3 Learner.", call. = FALSE)
    grid <- grids[[label]]
    if (is.null(grid) || !length(grid)) grid <- data.frame(row.names = 1L)
    if (!is.data.frame(grid)) grid <- expand.grid(grid, KEEP.OUT.ATTRS = FALSE,
                                                 stringsAsFactors = FALSE)
    if (!nrow(grid) || anyDuplicated(grid) || anyDuplicated(names(grid)) ||
        "model_class" %in% names(grid))
      stop("Each grid needs unique configurations and parameter names.", call. = FALSE)
    if (!all(names(grid) %in% learner$param_set$ids()))
      stop("Unknown parameter for model class ", label, ".", call. = FALSE)
    for (j in seq_len(nrow(grid))) {
      pars <- lapply(grid[j, , drop = FALSE], function(x) {
        if (is.factor(x)) as.character(x) else x
      })
      if (any(vapply(pars, anyNA, logical(1))))
        stop("Grid values cannot be NA; omit inactive parameters.", call. = FALSE)
      clone <- learner$clone(deep = TRUE)
      values <- clone$param_set$values
      values[names(pars)] <- pars
      clone$param_set$values <- values
      configured[[length(configured) + 1L]] <- clone
      domains[[length(domains) + 1L]] <- c(list(model_class = label), pars)
      ids <- c(ids, paste0(label, "-", sprintf("%03d", j)))
    }
  }
  # Bind heterogeneous parameter spaces without coercing every column to text.
  columns <- unique(unlist(lapply(domains, names), use.names = FALSE))
  domain <- as.data.frame(stats::setNames(lapply(columns, function(column) {
    values <- lapply(domains, function(row) if (is.null(row[[column]])) NA else row[[column]])
    unlist(values, use.names = FALSE)
  }), columns), stringsAsFactors = FALSE)
  names(configured) <- ids
  structure(list(domain = domain, ids = ids, learners = configured),
            class = "cashomon_candidates")
}
