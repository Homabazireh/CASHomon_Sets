test_that("verified models meet the threshold and all fits are accounted for", {
  models <- regression_fixture()
  expect_length(models$models, 4L)
  expect_true(models$pool_fully_evaluated)
  expect_true(all(models$members$loss <= models$threshold))
  expect_lte(nrow(models$search$observations), 2L)
  expect_equal(nrow(models$search$observations) + models$n_verification, 4L)
})
