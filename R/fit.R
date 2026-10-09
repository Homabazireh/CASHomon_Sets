#' Find and fit an empirical CASHomon set
#'
#' Learners are fitted on train_rows and scored on validation_rows. Search uses
#' a fixed seed per candidate and no repeated evaluations. After Algorithm 1,
#' unevaluated members of L are fitted and verified; verify_all evaluates the
#' entire remaining pool. The returned models all meet the final empirical
#' threshold relative to the best evaluated configuration. This is not a
#' guarantee about population risk or unobserved candidates.
#' @param task An mlr3 TaskRegr or TaskClassif.
#' @param candidates Output of cashomon_candidates.
#' @param train_rows,validation_rows Disjoint, nonempty task row IDs.
#' @param measure Minimizing mlr3 measure; defaults to MSE or classification error.
#' @param epsilon_rel,epsilon_abs Tolerances in relative and absolute loss units.
#' @param budget Maximum evaluations during active search (verification is extra).
#' @param search_control Named list of remaining truvarimp arguments, e.g.
#'   kernel, beta, eta, prior_mean, cost or noise.
#' @param verify_all Evaluate every remaining candidate after active search.
#' @param seed Seed for deterministic per-candidate fits, restored on exit.
#' @return A cashomon_set with named fitted models, member table, full archive,
#'   algorithm result, threshold, task, measure and original row partitions.
#' @details
#' Verification fits are additional to the search budget and are recorded in
#' \code{n_verification}. With partial evaluation the empirical threshold need
#' not equal the threshold for the entire candidate pool. Models are never
#' refitted on validation or explanation rows.
#' @seealso \code{\link{cashomon_pfi}}, \code{\link{truvarimp}}
#' @export
fit_cashomon <- function(task, candidates, train_rows, validation_rows,
                         measure = NULL, epsilon_rel = 0.05, epsilon_abs = 0,
                         budget = min(30L, nrow(candidates$domain)),
                         search_control = list(), verify_all = FALSE, seed = 1L) {
  .need("mlr3")
  if (!inherits(task, c("TaskRegr", "TaskClassif")))
    stop("task must be an mlr3 regression or classification task.", call. = FALSE)
  if (!inherits(candidates, "cashomon_candidates"))
    stop("Use cashomon_candidates() to create candidates.", call. = FALSE)
  .number(seed, "seed", 0, .Machine$integer.max, TRUE)
  train_rows <- .rows(train_rows, task, "train_rows")
  validation_rows <- .rows(validation_rows, task, "validation_rows")
  if (length(intersect(train_rows, validation_rows)))
    stop("Training and validation rows must be disjoint.", call. = FALSE)
  if (is.null(measure)) measure <- mlr3::msr(if (task$task_type == "regr")
    "regr.mse" else "classif.ce")
  .check_measure(measure, task)
  if (!is.logical(verify_all) || length(verify_all) != 1L || is.na(verify_all))
    stop("verify_all must be TRUE or FALSE.", call. = FALSE)
  if (!is.list(search_control) || (length(search_control) &&
      (is.null(names(search_control)) || anyDuplicated(names(search_control)))))
    stop("search_control must be a uniquely named list.", call. = FALSE)
  allowed <- setdiff(names(formals(truvarimp)),
    c("domain", "objective", "epsilon_rel", "epsilon_abs", "budget", "allow_repeats", "seed"))
  if (!all(names(search_control) %in% allowed))
    stop("Unsupported search_control argument: ",
      paste(setdiff(names(search_control), allowed), collapse = ", "), call. = FALSE)
  for (learner in candidates$learners) mlr3::assert_learner(learner, task = task)
  n <- length(candidates$learners)
  losses <- rep(NA_real_, n)
  fitted <- vector("list", n)
  evaluate <- function(index) {
    if (!is.na(losses[index])) return(losses[index])
    learner <- candidates$learners[[index]]$clone(deep = TRUE)
    .with_seed(as.integer((as.double(seed) + index - 1) %% .Machine$integer.max), {
      tryCatch({
        learner$train(task, row_ids = train_rows)
        score <- as.numeric(learner$predict(task, row_ids = validation_rows)$score(measure))
        .number(score, "validation loss")
        if (epsilon_rel > 0 && score < 0)
          stop("Relative tolerance requires a nonnegative loss.")
        fitted[[index]] <<- learner
        losses[index] <<- score
      }, error = function(e) stop("Candidate ", candidates$ids[index], ": ",
        conditionMessage(e), call. = FALSE))
    })
    losses[index]
  }
  domain <- candidates$domain
  # Preserve indices via row names; do not put identifiers into GP features.
  rownames(domain) <- as.character(seq_len(n))
  scale <- if (task$task_type == "regr") {
    y <- task$data(rows = train_rows, cols = task$target_names)[[1L]]
    max(stats::var(y), 1e-4, na.rm = TRUE)
  } else 1
  defaults <- list(kernel = cashomon_kernel(domain, variance = scale^2),
                   eta = scale, prior_mean = scale, noise = 0)
  defaults[names(search_control)] <- search_control
  search <- do.call(truvarimp, c(list(domain = domain,
    objective = function(row) evaluate(as.integer(rownames(row))),
    epsilon_rel = epsilon_rel, epsilon_abs = epsilon_abs, budget = budget,
    allow_repeats = FALSE, seed = seed), defaults))
  evaluated_in_search <- which(!is.na(losses))
  to_verify <- if (verify_all) seq_len(n) else search$L
  for (index in setdiff(to_verify, evaluated_in_search)) evaluate(index)
  if (all(is.na(losses))) stop("No candidate was evaluated.", call. = FALSE)
  threshold <- min(losses, na.rm = TRUE) * (1 + epsilon_rel) + epsilon_abs
  keep <- which(!is.na(losses) & losses <= threshold)
  status <- rep("U", n)
  status[search$L] <- "L"
  status[search$H] <- "H"
  archive <- data.frame(index = seq_len(n), model_id = candidates$ids,
    model_class = domain$model_class, loss = losses, search_status = status,
    evaluated_in_search = seq_len(n) %in% evaluated_in_search,
    member = seq_len(n) %in% keep, stringsAsFactors = FALSE)
  structure(list(models = stats::setNames(fitted[keep], candidates$ids[keep]),
    members = archive[keep, , drop = FALSE], archive = archive,
    search = search, threshold = threshold, best_loss = min(losses, na.rm = TRUE),
    epsilon_rel = epsilon_rel, epsilon_abs = epsilon_abs,
    n_verification = sum(!is.na(losses)) - length(evaluated_in_search),
    pool_fully_evaluated = all(!is.na(losses)), task = task$clone(deep = TRUE),
    measure = measure$clone(deep = TRUE), train_rows = train_rows,
    validation_rows = validation_rows, seed = seed), class = "cashomon_set")
}

#' @rdname fit_cashomon
#' @param x Object to print.
#' @param ... Unused.
#' @export
print.cashomon_set <- function(x, ...) {
  cat("CASHomon set:", nrow(x$members), "fitted models from",
      length(unique(x$members$model_class)), "model classes\n",
      " Empirical loss threshold:", format(x$threshold, digits = 5),
      " (best evaluated:", format(x$best_loss, digits = 5), ")\n",
      " Search evaluations:", nrow(x$search$observations),
      " Additional verification fits:", x$n_verification, "\n",
      " Entire candidate pool evaluated:", x$pool_fully_evaluated, "\n")
  invisible(x)
}
