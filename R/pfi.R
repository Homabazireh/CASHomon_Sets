# A public mlr3 Learner adapter whose training operation only installs an already
# fitted model. This works even with xplainfi releases that resample/refit the
# supplied learner, and never retrains a selected stochastic learner.
.frozen_learner <- function(fitted) {
  .need("R6")
  regression <- fitted$task_type == "regr"
  generator <- R6::R6Class(
    if (regression) "LearnerRegrCashomonFrozen" else "LearnerClassifCashomonFrozen",
    inherit = if (regression) mlr3::LearnerRegr else mlr3::LearnerClassif,
    public = list(initialize = function() {
      super$initialize(id = paste0(fitted$task_type, ".cashomon_frozen"),
        feature_types = fitted$feature_types,
        predict_types = intersect(fitted$predict_types, c("response", "prob")),
        properties = intersect(fitted$properties,
          c("twoclass", "multiclass", "missings", "weights")),
        packages = character())
      self$predict_type <- fitted$predict_type
    }),
    private = list(
      .train = function(task) list(fitted = fitted$clone(deep = TRUE)),
      .predict = function(task) {
        pred <- self$model$fitted$predict_newdata(task$data(cols = task$feature_names))
        if (self$predict_type == "prob") list(prob = pred$prob) else
          list(response = pred$response)
      }
    )
  )
  generator$new()
}

#' Permutation feature importance for every retained fitted model
#'
#' Runs xplainfi::PFI on a shared, independent explanation holdout. A frozen
#' learner adapter preserves the exact selected fit even when xplainfi trains
#' its input learner. No new fitted predictor is substituted. All permutations
#' and feature means are retained; model spread and permutation spread are
#' reported separately. Uses loss differences (permuted minus baseline).
#' @param object A fitted cashomon_set.
#' @param test_rows Task row IDs used only for explanations, disjoint from both
#'   training and validation. Defaults to all unused task rows.
#' @param features Character vector of features; NULL means all task features.
#' @param n_repeats Positive number of permutations per feature and model.
#' @param seed Seed reset to the same value for each model for comparability.
#' @param keep_explainers Retain the underlying xplainfi R6 objects.
#' @return A cashomon_pfi with tidy scores and per-model importance data frames,
#'   model metadata, settings and optionally xplainfi objects.
#' @details
#' Requires mlr3, xplainfi and R6. Permutation percentiles quantify shuffle
#' variation conditional on the model and holdout, not sampling confidence.
#' Negative PFI values are retained.
#' @seealso \code{\link{plot_cashomon_pfi}}, \code{\link{summarise_cashomon_pfi}}
#' @export
cashomon_pfi <- function(object, test_rows = NULL, features = NULL,
                         n_repeats = 30L, seed = 1L, keep_explainers = FALSE) {
  .need("mlr3")
  .need("xplainfi")
  .need("R6")
  if (!inherits(object, "cashomon_set") || !length(object$models))
    stop("object must be a nonempty fitted cashomon_set.", call. = FALSE)
  .number(n_repeats, "n_repeats", 1, .Machine$integer.max, TRUE)
  .number(seed, "seed", 0, .Machine$integer.max, TRUE)
  if (!is.logical(keep_explainers) || length(keep_explainers) != 1L || is.na(keep_explainers))
    stop("keep_explainers must be TRUE or FALSE.", call. = FALSE)
  task <- object$task$clone(deep = TRUE)
  if (is.null(test_rows)) test_rows <- setdiff(task$row_ids,
    c(object$train_rows, object$validation_rows))
  test_rows <- .rows(test_rows, task, "test_rows")
  if (length(test_rows) < 2L) stop("PFI needs at least two test rows.", call. = FALSE)
  if (length(intersect(test_rows, c(object$train_rows, object$validation_rows))))
    stop("PFI rows must be disjoint from training and model-selection validation rows.",
         call. = FALSE)
  if (is.null(features)) features <- task$feature_names
  if (!is.character(features) || !length(features) || anyNA(features) ||
      anyDuplicated(features) || !all(features %in% task$feature_names))
    stop("features must be unique feature names from the task.", call. = FALSE)
  resampling <- mlr3::rsmp("custom")
  resampling$instantiate(task, train_sets = list(object$train_rows), test_sets = list(test_rows))
  scores <- importances <- explainers <- list()
  for (id in names(object$models)) {
    learner <- object$models[[id]]
    row <- object$members[match(id, object$members$model_id), , drop = FALSE]
    explainer <- .with_seed(seed, {
      pfi <- xplainfi::PFI$new(task = task$clone(deep = TRUE),
        learner = .frozen_learner(learner), measure = object$measure$clone(deep = TRUE),
        resampling = resampling$clone(deep = TRUE), features = features,
        n_repeats = as.integer(n_repeats))
      pfi$compute()
      pfi
    })
    raw <- as.data.frame(explainer$scores())
    if (!all(c("feature", "importance", "iter_repeat") %in% names(raw)))
      stop("Unsupported xplainfi scores() schema. Expected feature, importance and iter_repeat.",
           call. = FALSE)
    if (any(!is.finite(raw$importance)))
      stop("xplainfi returned non-finite importance for ", id, ".", call. = FALSE)
    # Verify that the adapter reproduces predictions from the selected model.
    baseline <- as.numeric(learner$predict(task, row_ids = test_rows)$score(object$measure))
    fitted_baseline <- as.numeric(explainer$resample_result$aggregate(object$measure))
    if (!isTRUE(all.equal(baseline, fitted_baseline, tolerance = 1e-10)))
      stop("Frozen learner did not preserve baseline predictions for ", id, ".", call. = FALSE)
    raw$model_id <- id
    raw$model_class <- row$model_class
    raw$validation_loss <- row$loss
    raw$baseline_loss <- baseline
    scores[[id]] <- raw
    importances[[id]] <- do.call(rbind, lapply(features, function(feature) {
      values <- raw$importance[raw$feature == feature]
      if (length(values) != n_repeats)
        stop("Unexpected number of PFI repeats for ", id, "/", feature, ".", call. = FALSE)
      data.frame(model_id = id, model_class = row$model_class, feature = feature,
        importance = mean(values), permutation_sd = if (length(values) > 1) stats::sd(values) else NA_real_,
        permutation_q05 = unname(stats::quantile(values, 0.05)),
        permutation_q95 = unname(stats::quantile(values, 0.95)),
        n_repeats = length(values), validation_loss = row$loss, baseline_loss = baseline)
    }))
    if (keep_explainers) explainers[[id]] <- explainer
  }
  importance <- do.call(rbind, importances)
  rownames(importance) <- NULL
  importance$rank <- stats::ave(importance$importance, importance$model_id,
    FUN = function(x) rank(-x, ties.method = "average"))
  scores <- do.call(rbind, scores)
  rownames(scores) <- NULL
  structure(list(scores = scores, importance = importance, members = object$members,
    explainers = explainers, measure = object$measure$id,
    threshold = object$threshold, test_rows = test_rows, features = features,
    n_repeats = n_repeats, seed = seed, relation = "difference"), class = "cashomon_pfi")
}

#' Summarize variation across fitted models
#'
#' Describes empirical feature-importance ranges after averaging each model's
#' permutations. Each fitted model receives equal weight.
#'
#' @param object A cashomon_pfi object.
#' @param by_class Summarize model classes separately.
#' @return Data frame of empirical model minima, maxima, median and 5/95 percentiles.
#'   These are descriptive finite-set summaries, not population confidence bounds.
#' @export
summarise_cashomon_pfi <- function(object, by_class = FALSE) {
  if (!inherits(object, "cashomon_pfi")) stop("Expected cashomon_pfi.", call. = FALSE)
  if (!is.logical(by_class) || length(by_class) != 1L || is.na(by_class))
    stop("by_class must be TRUE or FALSE.", call. = FALSE)
  d <- object$importance
  grouping <- if (by_class) list(d$feature, d$model_class) else list(d$feature)
  groups <- split(d, do.call(interaction, c(grouping, list(drop = TRUE, lex.order = TRUE))))
  result <- do.call(rbind, lapply(groups, function(x) {
    data.frame(feature = x$feature[1L],
      model_class = if (by_class) x$model_class[1L] else "All models",
      n_models = nrow(x), minimum = min(x$importance),
      q05 = unname(stats::quantile(x$importance, 0.05)),
      median = stats::median(x$importance),
      q95 = unname(stats::quantile(x$importance, 0.95)), maximum = max(x$importance),
      positive_fraction = mean(x$importance > 0),
      median_rank = stats::median(x$rank))
  }))
  rownames(result) <- NULL
  result[order(-result$median), , drop = FALSE]
}

#' @rdname cashomon_pfi
#' @param x Object to print.
#' @param ... Unused.
#' @export
print.cashomon_pfi <- function(x, ...) {
  cat("CASHomon PFI:", length(unique(x$importance$model_id)), "models x",
    length(x$features), "features x", x$n_repeats, "permutations\n",
    " Loss difference:", x$measure, "; independent test rows:", length(x$test_rows), "\n")
  invisible(x)
}
