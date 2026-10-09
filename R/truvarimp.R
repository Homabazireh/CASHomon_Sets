#' Finite-domain TruVaRImp (Algorithm 1)
#'
#' Uses a fixed GP prior, exact rank-one posterior updates, and cost-weighted
#' truncated variance reduction over both U and M. Membership in L/H is permanent,
#' as in the paper. Bounds are not intersected across iterations. The tolerance
#' defines h = min(c) * (1 + epsilon_rel) + epsilon_abs.
#' @param domain Nonempty data frame; rows are candidate configurations.
#' @param objective Function taking a one-row data frame and returning one loss.
#' @param kernel Prior covariance matrix; defaults to cashomon_kernel(domain).
#' @param epsilon_rel,epsilon_abs Nonnegative near-optimality tolerances.
#'   Relative tolerances assume nonnegative latent losses; noisy observations
#'   may be negative.
#' @param budget Maximum number of objective evaluations.
#' @param noise Observation noise VARIANCE, scalar or one value per candidate.
#' @param cost Positive evaluation cost, scalar or one value per candidate.
#' @param beta Positive scalar or function of epoch giving squared CI multiplier.
#' @param eta Initial positive truncation width, in objective units.
#' @param r Epoch shrink factor strictly between zero and one.
#' @param delta Positive epoch slack.
#' @param prior_mean Scalar or one finite value per candidate.
#' @param allow_repeats Whether to allow repeated noisy evaluations (paper default).
#' @param seed Optional local random seed. Ties use candidate row order.
#' @return A truvarimp_result with integer-index sets L/H/U/M, posterior,
#'   observations, trace, bounds, parameters and stopping reason.
#' @details
#' The target threshold uses the unknown minimum. Confidence multipliers are
#' user choices, not automatic calibrations of theoretical coverage. Search
#' stops at the budget, a complete partition, or exhausted evaluable candidates.
#' @references Ewald et al. (2026), \doi{10.48550/arXiv.2603.15321}.
#' @seealso \code{\link{fit_cashomon}}, \code{\link{cashomon_kernel}}
#' @examples
#' domain <- data.frame(x = seq(0, 1, length.out = 12))
#' result <- truvarimp(domain, function(row) (row$x - 0.3)^2,
#'   epsilon_abs = 0.05, noise = 0, budget = 8)
#' print(result)
#' @export
truvarimp <- function(domain, objective, kernel = NULL, epsilon_rel = 0.05,
                      epsilon_abs = 0, budget = nrow(domain), noise = 1e-6,
                      cost = 1, beta = 4, eta = 1, r = 0.5, delta = 0.1,
                      prior_mean = 0, allow_repeats = TRUE, seed = NULL) {
  if (!is.data.frame(domain) || !nrow(domain))
    stop("domain must be a nonempty data frame.", call. = FALSE)
  if (!is.function(objective)) stop("objective must be a function.", call. = FALSE)
  n <- nrow(domain)
  .number(budget, "budget", 1, .Machine$integer.max, TRUE)
  .number(epsilon_rel, "epsilon_rel", 0)
  .number(epsilon_abs, "epsilon_abs", 0)
  .number(eta, "eta", .Machine$double.eps)
  .number(r, "r", .Machine$double.eps, 1 - .Machine$double.eps)
  .number(delta, "delta", .Machine$double.eps)
  if (!is.logical(allow_repeats) || length(allow_repeats) != 1L || is.na(allow_repeats))
    stop("allow_repeats must be TRUE or FALSE.", call. = FALSE)
  noise <- .vector(noise, n, "noise")
  cost <- .vector(cost, n, "cost", positive = TRUE)
  beta_at <- function(epoch) {
    b <- if (is.function(beta)) beta(epoch) else beta
    .number(b, "beta(epoch)", .Machine$double.eps)
    b
  }
  beta_at(1L)
  if (is.null(kernel)) kernel <- cashomon_kernel(domain,
    class_col = if ("model_class" %in% names(domain)) "model_class" else NULL)
  if (!is.matrix(kernel) || !is.numeric(kernel) ||
      !identical(dim(kernel), c(n, n)) || any(!is.finite(kernel)) ||
      !isSymmetric(kernel, tol = 1e-10) || any(diag(kernel) < 0))
    stop("kernel must be a finite symmetric n-by-n covariance matrix.", call. = FALSE)
  if (min(eigen(kernel, symmetric = TRUE, only.values = TRUE)$values) <
      -1e-8 * max(1, max(diag(kernel))))
    stop("kernel must be positive semidefinite.", call. = FALSE)
  if (length(prior_mean) == 1L) prior_mean <- rep(prior_mean, n)
  if (!is.numeric(prior_mean) || length(prior_mean) != n || any(!is.finite(prior_mean)))
    stop("prior_mean must be finite, scalar or length n.", call. = FALSE)

  .with_seed(seed, {
    mu <- prior_mean
    covariance <- kernel
    L <- H <- integer()
    U <- M <- seq_len(n)
    epoch <- 1L
    observations <- data.frame(iteration = integer(), index = integer(), loss = double())
    trace <- list()
    lower <- upper <- rep(NA_real_, n)
    h_opt <- h_pes <- NA_real_
    reason <- "budget"
    for (iteration in seq_len(budget)) {
      b <- beta_at(epoch)
      v <- pmax(diag(covariance), 0)
      eligible <- which(v > 0 & v + noise > 0)
      if (!allow_repeats) eligible <- setdiff(eligible, observations$index)
      if (!length(eligible)) { reason <- "no_evaluable_candidates"; break }
      delta_sum <- function(variance, indices, p) {
        sum(pmax(p^2 * b * variance[indices] - eta^2, 0))
      }
      current <- delta_sum(v, U, 1) + delta_sum(v, M, 1 + epsilon_rel)
      acquisition <- rep(-Inf, n)
      for (j in eligible) {
        lookahead <- pmax(v - covariance[, j]^2 / (v[j] + noise[j]), 0)
        acquisition[j] <- max(0, current - delta_sum(lookahead, U, 1) -
          delta_sum(lookahead, M, 1 + epsilon_rel)) / cost[j]
      }
      selected <- which.max(acquisition)
      loss <- objective(domain[selected, , drop = FALSE])
      .number(loss, "objective return value")
      if (epsilon_rel > 0 && noise[selected] == 0 && loss < 0)
        stop("Relative tolerance requires nonnegative noise-free objective values.", call. = FALSE)
      observations <- rbind(observations,
        data.frame(iteration = iteration, index = selected, loss = loss))

      # Equations (2)-(3), applied as a rank-one Gaussian conditioning update.
      column <- covariance[, selected]
      denominator <- v[selected] + noise[selected]
      mu <- mu + column * (loss - mu[selected]) / denominator
      covariance <- covariance - tcrossprod(column) / denominator
      covariance <- (covariance + t(covariance)) / 2
      diag(covariance) <- pmax(diag(covariance), 0)
      if (noise[selected] == 0) {
        covariance[selected, ] <- covariance[, selected] <- 0
        mu[selected] <- loss
      }
      sd <- sqrt(diag(covariance))
      lower <- mu - sqrt(b) * sd
      upper <- mu + sqrt(b) * sd
      c_pes <- min(upper[M])
      h_pes <- (1 + epsilon_rel) * c_pes + epsilon_abs
      h_opt <- (1 + epsilon_rel) * min(lower[M]) + epsilon_abs
      # Thresholds use M from the previous iteration, before filtering it.
      low <- U[upper[U] <= h_opt]
      high <- setdiff(U[lower[U] > h_pes], low)
      L <- union(L, low)
      H <- union(H, high)
      U <- setdiff(U, c(low, high))
      M <- M[lower[M] <= c_pes]
      if (!length(M)) stop("No potential minimizers: numerical failure.", call. = FALSE)
      trace[[length(trace) + 1L]] <- data.frame(iteration = iteration,
        index = selected, loss = loss, acquisition = acquisition[selected],
        epoch = epoch, eta = eta, beta = b, n_low = length(L), n_high = length(H),
        n_uncertain = length(U), n_minimizers = length(M),
        threshold_lower = h_opt, threshold_upper = h_pes)
      # A finite implementation stops once the requested partition is complete.
      if (!length(U)) { reason <- "classified"; break }
      if (!allow_repeats && length(unique(observations$index)) == n) {
        reason <- "candidates_exhausted"; break
      }
      max_u <- max(c(0, sd[U]))
      max_m <- max(c(0, sd[M]))
      # Zero uncertainty would otherwise make the paper's epoch loop infinite.
      if (max(max_u, max_m) == 0) { reason <- "zero_variance"; break }
      while (sqrt(beta_at(epoch)) * max_u <= (1 + delta) * eta &&
             sqrt(beta_at(epoch)) * max_m <= (1 + delta) * eta / (1 + epsilon_rel)) {
        epoch <- epoch + 1L
        eta <- eta * r
      }
    }
    structure(list(domain = domain, L = sort(L), H = sort(H), U = sort(U),
      M = sort(M), posterior = data.frame(mean = mu, sd = sqrt(diag(covariance)),
        lower = lower, upper = upper), covariance = covariance,
      observations = observations,
      trace = if (length(trace)) do.call(rbind, trace) else data.frame(),
      threshold = c(lower = h_opt, upper = h_pes),
      parameters = list(epsilon_rel = epsilon_rel, epsilon_abs = epsilon_abs,
        budget = budget, noise = noise, cost = cost, allow_repeats = allow_repeats),
      stop_reason = reason), class = "truvarimp_result")
  })
}

#' @rdname truvarimp
#' @param x Object to print.
#' @param ... Unused.
#' @export
print.truvarimp_result <- function(x, ...) {
  cat("TruVaRImp:", nrow(x$domain), "candidates;", nrow(x$observations), "evaluations\n",
      " L (inside):", length(x$L), " H (outside):", length(x$H),
      " U (uncertain):", length(x$U), " M (possible best):", length(x$M),
      "\n Stopped:", x$stop_reason, "\n")
  invisible(x)
}
