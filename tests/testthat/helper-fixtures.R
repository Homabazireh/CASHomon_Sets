# Explicit plot fixture: these values are not experimental PFI results.
pfi_fixture <- function() {
  d <- expand.grid(model_id = c("tree-1", "tree-2", "linear-1"),
    feature = c("signal", "proxy", "noise"), stringsAsFactors = FALSE)
  d$model_class <- ifelse(d$model_id == "linear-1", "Linear", "Tree")
  d$importance <- c(4, 2, 5, 1, 3, 0.8, -0.02, 0.04, 0)
  d$permutation_q05 <- d$importance - 0.1
  d$permutation_q95 <- d$importance + 0.1
  d$validation_loss <- rep(c(1.05, 1.1, 1), 3)
  d$rank <- ave(d$importance, d$model_id, FUN = function(x) rank(-x))
  structure(list(importance = d, features = unique(d$feature),
    n_repeats = 10L, measure = "regr.mse", threshold = 1.2), class = "cashomon_pfi")
}

regression_fixture <- function() {
  skip_if_not_installed("mlr3")
  skip_if_not_installed("rpart")
  task <- mlr3::as_task_regr(mtcars, target = "mpg")
  candidates <- cashomon_candidates(list(Tree = mlr3::lrn("regr.rpart")),
    list(Tree = list(cp = c(0.001, 0.05), maxdepth = c(2L, 4L))))
  fit_cashomon(task, candidates, 1:16, 17:24, epsilon_rel = 0,
    epsilon_abs = 1000, budget = 2, verify_all = TRUE)
}
