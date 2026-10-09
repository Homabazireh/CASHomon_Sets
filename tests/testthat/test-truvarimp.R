test_that("sequential GP conditioning agrees with an independent batch solve", {
  d <- data.frame(x = c(0, 0.3, 0.6, 1))
  k <- cashomon_kernel(d, class_col = NULL, lengthscale = 0.4, variance = 2)
  truth <- c(0.2, 0.9, 1.1, 0.5)
  noise <- c(0.02, 0.1, 0.03, 0.05)
  fit <- truvarimp(d, function(row) truth[as.integer(rownames(row))], kernel = k,
    epsilon_rel = 0, epsilon_abs = 0.1, prior_mean = 0.3, noise = noise,
    beta = 16, budget = 3, allow_repeats = FALSE)
  ii <- fit$observations$index
  cross <- k[, ii, drop = FALSE]
  system <- k[ii, ii, drop = FALSE] + diag(noise[ii], nrow = length(ii))
  expected_mu <- 0.3 + cross %*% solve(system, truth[ii] - 0.3)
  expected_cov <- k - cross %*% solve(system, t(cross))
  expect_equal(fit$posterior$mean, as.numeric(expected_mu), tolerance = 1e-9)
  expect_equal(fit$covariance, expected_cov, tolerance = 1e-9)
  expect_equal(nrow(fit$observations), 3L)
})

test_that("acquisition accounts for costs and relative scaling of M", {
  d <- data.frame(x = c(0, 0.3, 0.6, 1))
  k <- cashomon_kernel(d, class_col = NULL, lengthscale = 0.4, variance = 2)
  noise <- c(0.02, 0.1, 0.03, 0.05)
  cost <- c(0.9, 3, 1.3, 2)
  v <- diag(k)
  beta <- 4
  eta <- 0.5
  eps <- 0.5
  potential <- function(var) sum(pmax(beta * var - eta^2, 0)) +
    sum(pmax((1 + eps)^2 * beta * var - eta^2, 0))
  gain <- vapply(seq_len(nrow(k)), function(j) {
    after <- pmax(v - k[, j]^2 / (v[j] + noise[j]), 0)
    (potential(v) - potential(after)) / cost[j]
  }, numeric(1))
  one <- truvarimp(d, function(row) 0.2, kernel = k, epsilon_rel = eps,
    beta = beta, eta = eta, noise = noise, cost = cost, budget = 1)
  expect_equal(one$observations$index, which.max(gain))
  expect_equal(one$trace$acquisition, max(gain), tolerance = 1e-9)
})

test_that("noise-free measurements recover a known level set and partition", {
  domain <- data.frame(x = seq_len(6))
  loss <- c(1, 1.1, 1.2, 1.31, 2, 4)
  result <- truvarimp(domain, function(row) loss[row$x], kernel = diag(25, 6),
    epsilon_rel = 0.1, epsilon_abs = 0.1, prior_mean = 2,
    eta = 1, beta = 4, noise = 0, budget = 6)
  expect_identical(result$L, which(loss <= 1.2))
  expect_identical(result$H, which(loss > 1.2))
  expect_length(result$U, 0L)
  expect_identical(result$stop_reason, "classified")
  expect_identical(sort(c(result$L, result$H, result$U)), seq_len(nrow(domain)))
  expect_length(intersect(result$L, result$H), 0L)
  expect_length(intersect(result$L, result$U), 0L)
  expect_length(intersect(result$H, result$U), 0L)
  expect_true(all(result$trace$n_low + result$trace$n_high +
    result$trace$n_uncertain == nrow(domain)))
  expect_true(all(diff(result$trace$n_low) >= 0))
  expect_true(all(diff(result$trace$n_high) >= 0))
})

test_that("repeated noisy queries reduce uncertainty", {
  fit <- truvarimp(data.frame(x = 1), function(row) 1, kernel = matrix(1),
    epsilon_rel = 0, epsilon_abs = 0, noise = 1, budget = 4)
  expect_equal(nrow(fit$observations), 4L)
  expect_true(all(fit$observations$index == 1))
  expect_equal(fit$posterior$sd^2, 1 / 5, tolerance = 1e-9)
  singleton <- truvarimp(data.frame(x = 1), function(row) 0,
    noise = 0, epsilon_rel = 0, budget = 1)
  expect_identical(singleton$L, 1L)
  expect_identical(singleton$stop_reason, "classified")
})

test_that("local seeds preserve caller state on success and failure", {
  d <- data.frame(x = c(0, 0.3, 0.6, 1))
  set.seed(8)
  state <- .Random.seed
  truvarimp(d, function(row) runif(1), budget = 2, seed = 99)
  expect_identical(state, .Random.seed)
  expect_error(truvarimp(d, function(row) stop("failed"), seed = 99), "failed")
  expect_identical(state, .Random.seed)
})

test_that("invalid search inputs fail and negative noisy observations are allowed", {
  d <- data.frame(x = c(0, 0.3, 0.6, 1))
  expect_error(truvarimp(d, function(row) 1, budget = 0), "budget")
  expect_error(truvarimp(d, function(row) -1, noise = 0), "nonnegative")
  noisy_negative <- truvarimp(d, function(row) -0.1, noise = 1, budget = 1)
  expect_equal(noisy_negative$observations$loss, -0.1)
  expect_error(truvarimp(d, function(row) NA_real_), "objective return value")
  expect_error(truvarimp(d, function(row) 1, noise = -1), "noise")
  expect_error(truvarimp(d, function(row) 1, cost = 0), "cost")
  expect_error(truvarimp(d, function(row) 1, r = 1), "r")
  expect_error(truvarimp(d, function(row) 1, kernel = diag(2)), "covariance matrix")
  bad <- diag(4)
  bad[1, 2] <- bad[2, 1] <- 2
  expect_error(truvarimp(d, function(row) 1, kernel = bad), "positive semidefinite")
})
