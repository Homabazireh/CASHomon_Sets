test_that("the block kernel handles categorical and inactive parameters", {
  mixed <- data.frame(model_class = c("tree", "tree", "forest", "forest"),
    depth = c(2, 5, NA, NA), nodes = c(NA, NA, 3, 8),
    split = c("gini", "entropy", NA, NA))
  k <- cashomon_kernel(mixed)
  expect_true(all(k[1:2, 3:4] == 0))
  expect_gte(min(eigen(k, symmetric = TRUE)$values), -1e-10)
  expect_equal(diag(k), rep(1, 4))
  expect_error(cashomon_kernel(data.frame(x = 1)), "class_col")
})
