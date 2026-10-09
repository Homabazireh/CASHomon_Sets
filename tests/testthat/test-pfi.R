test_that("PFI preserves every fitted model, row separation and RNG state", {
  skip_if_not_installed("xplainfi")
  skip_if_not_installed("R6")
  models <- regression_fixture()
  before <- lapply(models$models, function(x) serialize(x$model, NULL))
  set.seed(41)
  state <- .Random.seed
  pfi <- cashomon_pfi(models, 25:32, features = c("wt", "hp"), n_repeats = 3,
    seed = 8, keep_explainers = TRUE)
  expect_identical(state, .Random.seed)
  expect_equal(nrow(pfi$importance), 8L)
  expect_equal(nrow(pfi$scores), 24L)
  expect_true(all(is.finite(pfi$importance$importance)))
  expect_identical(before, lapply(models$models, function(x) serialize(x$model, NULL)))
  again <- cashomon_pfi(models, 25:32, features = c("wt", "hp"), n_repeats = 3, seed = 8)
  expect_identical(pfi$importance, again$importance)
  expect_error(cashomon_pfi(models, 20:30), "disjoint")
})

test_that("the frozen adapter never retrains the selected learner", {
  skip_if_not_installed("xplainfi")
  skip_if_not_installed("R6")
  models <- regression_fixture()
  for (learner in models$models) {
    private <- learner$.__enclos_env__$private
    unlockBinding(".train", private)
    private$.train <- function(task) stop("Original learner must never be refitted")
    lockBinding(".train", private)
  }
  pfi <- cashomon_pfi(models, 25:32, features = "wt", n_repeats = 2)
  expect_equal(nrow(pfi$importance), length(models$models))
})

test_that("probability-based classification supports non-contiguous row IDs", {
  skip_if_not_installed("mlr3")
  skip_if_not_installed("xplainfi")
  skip_if_not_installed("R6")
  skip_if_not_installed("rpart")
  task <- mlr3::as_task_classif(iris, target = "Species")
  train <- c(1:25, 51:75, 101:125)
  valid <- c(26:37, 76:87, 126:137)
  test <- c(38:50, 88:100, 138:150)
  pool <- cashomon_candidates(list(Tree = mlr3::lrn("classif.rpart", predict_type = "prob")),
    list(Tree = list(cp = c(0.001, 0.05))))
  models <- fit_cashomon(task, pool, train, valid,
    measure = mlr3::msr("classif.logloss"), epsilon_rel = 0, epsilon_abs = 100,
    budget = 2, verify_all = TRUE)
  pfi <- cashomon_pfi(models, test, n_repeats = 2)
  expect_equal(nrow(pfi$importance), 8L)
  expect_true(all(is.finite(pfi$importance$importance)))
})

test_that("summaries average permutations before describing model variation", {
  fixture <- pfi_fixture()
  summary <- summarise_cashomon_pfi(fixture)
  expect_equal(summary$minimum[summary$feature == "signal"], 2)
  expect_equal(summary$maximum[summary$feature == "signal"], 5)
  expect_equal(summary$median[summary$feature == "signal"], 4)
  expect_equal(nrow(summarise_cashomon_pfi(fixture, by_class = TRUE)), 6L)
})
