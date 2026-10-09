# Supplemental demonstration when mlr3/xplainfi are unavailable.
# PFI is calculated directly in R, NOT by xplainfi. It is labeled in all outputs.
# Run from the repository root: Rscript inst/examples/offline-workflow.R
required <- c("cashomon", "rpart", "ranger", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install these packages first: ", paste(missing, collapse = ", "))

output <- file.path("artifacts", "direct-r-demo")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
backend <- "direct_R_permutation"
data_seed <- 2603L
model_seed <- 42L
permutation_seed <- 42L
n_repeats <- 30L
epsilon_rel <- 0.35
epsilon_abs <- 0
budget <- 10L

# Match the simulated data-generating process in the xplainfi example.
set.seed(data_seed)
n <- 700L
signal <- rnorm(n)
data <- data.frame(signal = signal, proxy = signal + rnorm(n, sd = 0.25),
  modifier = runif(n, -1, 1), noise = rnorm(n))
data$target <- 3 * signal + 1.5 * data$modifier^2 + rnorm(n, sd = 0.8)
rows <- sample(seq_len(n))
train <- rows[1:350]
validation <- rows[351:525]
test <- rows[526:700]
features <- setdiff(names(data), "target")
stopifnot(!length(intersect(train, validation)), !length(intersect(train, test)),
  !length(intersect(validation, test)))

tree_grid <- expand.grid(cp = c(0.0001, 0.003, 0.015), minsplit = c(10L, 25L))
forest_grid <- expand.grid(mtry = c(1L, 2L, 4L), min.node.size = c(3L, 10L, 25L))
domain <- rbind(
  data.frame(model_class = "Linear", cp = NA_real_, minsplit = NA_integer_,
    mtry = NA_integer_, min.node.size = NA_integer_),
  data.frame(model_class = "Tree", tree_grid, mtry = NA_integer_, min.node.size = NA_integer_),
  data.frame(model_class = "Forest", cp = NA_real_, minsplit = NA_integer_, forest_grid)
)
ids <- c("Linear-001", sprintf("Tree-%03d", seq_len(nrow(tree_grid))),
  sprintf("Forest-%03d", seq_len(nrow(forest_grid))))
rownames(domain) <- as.character(seq_len(nrow(domain)))
models <- vector("list", nrow(domain))
losses <- rep(NA_real_, nrow(domain))
predict_model <- function(model, newdata) {
  if (inherits(model, "ranger")) predict(model, data = newdata, num.threads = 1)$predictions else
    as.numeric(stats::predict(model, newdata = newdata))
}
evaluate <- function(index) {
  if (!is.na(losses[index])) return(losses[index])
  config <- domain[index, ]
  set.seed(model_seed + index - 1L)
  model <- switch(config$model_class,
    Linear = stats::lm(target ~ ., data = data[train, ]),
    Tree = rpart::rpart(target ~ ., data = data[train, ], method = "anova",
      control = rpart::rpart.control(cp = config$cp, minsplit = config$minsplit, xval = 0)),
    Forest = ranger::ranger(target ~ ., data = data[train, ], num.trees = 150,
      mtry = config$mtry, min.node.size = config$min.node.size,
      num.threads = 1, seed = model_seed + index - 1L)
  )
  prediction <- predict_model(model, data[validation, features])
  loss <- mean((data$target[validation] - prediction)^2)
  stopifnot(is.finite(loss), loss >= 0)
  models[[index]] <<- model
  losses[index] <<- loss
  loss
}

# Algorithm 1 actively chooses evaluations. Exhaustive verification then makes
# membership exact for the finite pool; its extra fits are recorded separately.
scale <- stats::var(data$target[train])
search <- cashomon::truvarimp(domain,
  function(row) evaluate(as.integer(rownames(row))),
  kernel = cashomon::cashomon_kernel(domain, variance = scale^2),
  epsilon_rel = epsilon_rel, epsilon_abs = epsilon_abs, budget = budget,
  noise = 0, prior_mean = scale, eta = scale, allow_repeats = FALSE, seed = model_seed)
searched <- which(!is.na(losses))
for (index in seq_len(nrow(domain))) evaluate(index)
threshold <- min(losses) * (1 + epsilon_rel) + epsilon_abs
keep <- which(losses <= threshold)
status <- rep("U", nrow(domain))
status[search$L] <- "L"
status[search$H] <- "H"
archive <- data.frame(model_id = ids, domain, validation_loss = losses,
  search_status = status, evaluated_in_search = seq_len(nrow(domain)) %in% searched,
  member = seq_len(nrow(domain)) %in% keep, row.names = NULL)
members <- archive[keep, , drop = FALSE]

# One shared permutation plan for every model reduces comparison noise. PFI uses
# held-out loss differences and the EXACT model fitted during candidate evaluation.
set.seed(permutation_seed)
permutations <- lapply(features, function(feature) {
  replicate(n_repeats, sample.int(length(test)), simplify = FALSE)
})
names(permutations) <- features
heldout <- data[test, features, drop = FALSE]
truth <- data$target[test]
raw <- summaries <- predictions <- list()
for (index in keep) {
  model <- models[[index]]
  original_model <- serialize(model, NULL)
  predicted <- predict_model(model, heldout)
  baseline <- mean((truth - predicted)^2)
  predictions[[ids[index]]] <- data.frame(model_id = ids[index], row_id = test,
    truth = truth, prediction = predicted)
  for (feature in features) {
    values <- vapply(permutations[[feature]], function(order) {
      shuffled <- heldout
      shuffled[[feature]] <- heldout[[feature]][order]
      mean((truth - predict_model(model, shuffled))^2)
    }, numeric(1))
    importance <- values - baseline
    key <- paste(ids[index], feature, sep = "/")
    raw[[key]] <- data.frame(model_id = ids[index], model_class = domain$model_class[index],
      feature = feature, iter_rsmp = 1L, iter_repeat = seq_len(n_repeats),
      baseline_loss = baseline, permuted_loss = values, importance = importance,
      validation_loss = losses[index], backend = backend)
    summaries[[key]] <- data.frame(model_id = ids[index], model_class = domain$model_class[index],
      feature = feature, importance = mean(importance), permutation_sd = stats::sd(importance),
      permutation_q05 = unname(stats::quantile(importance, 0.05)),
      permutation_q95 = unname(stats::quantile(importance, 0.95)),
      n_repeats = n_repeats, validation_loss = losses[index], baseline_loss = baseline,
      backend = backend)
  }
  stopifnot(identical(serialize(model, NULL), original_model))
}
scores <- do.call(rbind, raw)
importance <- do.call(rbind, summaries)
rownames(scores) <- rownames(importance) <- NULL
importance$rank <- ave(importance$importance, importance$model_id,
  FUN = function(x) rank(-x, ties.method = "average"))
# Reuse the package's plotting schema, explicitly identifying the alternative backend.
pfi <- structure(list(scores = scores, importance = importance, members = members,
  features = features, n_repeats = n_repeats, measure = "regr.mse", threshold = threshold,
  test_rows = test, seed = permutation_seed, relation = "difference", backend = backend),
  class = "cashomon_pfi")

# Numerical checks of membership, accounting, score aggregation and model coverage.
stopifnot(identical(keep, which(losses <= threshold)), all(members$validation_loss <= threshold),
  length(searched) <= budget, nrow(scores) == length(keep) * length(features) * n_repeats,
  nrow(importance) == length(keep) * length(features),
  all(is.finite(scores$importance)), setequal(unique(scores$model_id), members$model_id),
  isTRUE(all.equal(scores$importance, scores$permuted_loss - scores$baseline_loss)))
for (j in seq_len(nrow(importance))) {
  match <- scores$model_id == importance$model_id[j] & scores$feature == importance$feature[j]
  stopifnot(abs(mean(scores$importance[match]) - importance$importance[j]) < 1e-12)
}
# Independent algebraic audit for the linear model: if d is the permutation's
# change in prediction and e the original residual, the MSE change is d^2 - 2ed.
linear_index <- which(ids == "Linear-001")
if (linear_index %in% keep) {
  linear_model <- models[[linear_index]]
  residual <- truth - predict_model(linear_model, heldout)
  for (feature in features) {
    algebraic <- vapply(permutations[[feature]], function(order) {
      change <- unname(stats::coef(linear_model)[feature]) *
        (heldout[[feature]][order] - heldout[[feature]])
      mean(change^2 - 2 * residual * change)
    }, numeric(1))
    computed <- scores$importance[scores$model_id == "Linear-001" & scores$feature == feature]
    stopifnot(max(abs(algebraic - computed)) < 1e-10)
  }
}

write_csv <- function(x, name) utils::write.csv(x, file.path(output, name), row.names = FALSE)
write_csv(archive, "candidates.csv")
write_csv(members, "members.csv")
write_csv(search$trace, "search-trace.csv")
write_csv(search$observations, "search-observations.csv")
write_csv(scores, "pfi-permutations.csv")
write_csv(importance, "pfi-by-model.csv")
write_csv(cashomon::summarise_cashomon_pfi(pfi), "pfi-summary.csv")
write_csv(cashomon::summarise_cashomon_pfi(pfi, by_class = TRUE), "pfi-by-class.csv")
write_csv(do.call(rbind, predictions), "test-predictions.csv")
split <- rep(NA_character_, n)
split[train] <- "training"
split[validation] <- "validation"
split[test] <- "pfi_holdout"
write_csv(data.frame(row_id = seq_len(n), split = split, data), "simulated-data.csv")
# Ship the exact raw observations with the installed package as well as the results.
packaged_data <- file.path("inst", "extdata")
dir.create(packaged_data, recursive = TRUE, showWarnings = FALSE)
if (!file.copy(file.path(output, "simulated-data.csv"),
    file.path(packaged_data, "simulated-data.csv"), overwrite = TRUE)) {
  stop("Could not update the packaged raw demonstration dataset.")
}
plan <- do.call(rbind, lapply(features, function(feature) {
  do.call(rbind, lapply(seq_len(n_repeats), function(repeat_id) data.frame(
    feature = feature, repeat_id = repeat_id, row_id = test,
    donor_row_id = test[permutations[[feature]][[repeat_id]]])))
}))
write_csv(plan, "permutation-plan.csv")
run <- data.frame(backend = backend, simulated_data = TRUE, data_seed = data_seed,
  model_seed = model_seed, permutation_seed = permutation_seed, n_training = length(train),
  n_validation = length(validation), n_pfi_holdout = length(test),
  candidates = nrow(domain), search_evaluations = length(searched),
  additional_verification_fits = nrow(domain) - length(searched),
  retained_models = length(keep), retained_classes = length(unique(members$model_class)),
  epsilon_rel = epsilon_rel, epsilon_abs = epsilon_abs, best_validation_mse = min(losses),
  threshold = threshold, permutations_per_feature = n_repeats,
  pfi_mean_rows = nrow(importance), permutation_rows = nrow(scores))
write_csv(run, "run-summary.csv")
writeLines(capture.output(utils::sessionInfo()), file.path(output, "session-info.txt"))
saveRDS(list(search = search, models = stats::setNames(models, ids), members = members,
  pfi = pfi, data = data, splits = list(train = train, validation = validation, test = test),
  permutations = permutations, run = run), file.path(output, "workflow.rds"))

save_plot <- function(plot, name, width = 11, height = 6.5) {
  for (extension in c("png", "pdf")) ggplot2::ggsave(
    file.path(output, paste0(name, ".", extension)), plot,
    width = width, height = height, dpi = 180, bg = "#FAFBFD")
}
for (view in c("cloud", "heatmap", "ranks", "performance")) {
  plot <- cashomon::plot_cashomon_pfi(pfi, view)
  plot <- plot + ggplot2::labs(subtitle = paste0(plot$labels$subtitle,
    "\nSimulated data | PFI computed directly in R (fallback backend)"))
  save_plot(plot, paste0("pfi-", view))
}
save_plot(cashomon::plot_cashomon_search(search) + ggplot2::labs(
  subtitle = "Simulated data | active search before exhaustive candidate verification"), "search")
performance <- ggplot2::ggplot(archive, ggplot2::aes(x = validation_loss,
  y = reorder(model_id, -validation_loss), colour = model_class, shape = member)) +
  ggplot2::geom_vline(xintercept = threshold, linetype = "dashed", colour = "#536878") +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_colour_manual(values = c(Forest = "#0072B2", Linear = "#D55E00", Tree = "#009E73")) +
  ggplot2::scale_shape_manual(values = c(`FALSE` = 1, `TRUE` = 16),
    labels = c(`FALSE` = "Rejected", `TRUE` = "Retained")) +
  ggplot2::labs(title = "Which models belong to the CASHomon set?",
    subtitle = sprintf("Simulated data | best MSE %.3f | threshold %.3f (35%% tolerance)",
      min(losses), threshold), x = "Validation mean squared error", y = NULL,
    colour = "Model class", shape = "Membership",
    caption = "All 16 candidates were verified. PFI uses a separate 175-row holdout.") +
  ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(legend.position = "bottom",
    panel.grid.minor = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold", colour = "#152B3C"),
    plot.background = ggplot2::element_rect(fill = "#FAFBFD", colour = NA))
save_plot(performance, "model-performance")

summary <- cashomon::summarise_cashomon_pfi(pfi)
report <- c("# Demonstration results: direct-R PFI", "",
  "These are computed results from fitted models on simulated data, not plot fixtures.",
  "PFI was computed directly in R because xplainfi was unavailable. These are not xplainfi outputs.", "",
  "## Run", "",
  sprintf("- Candidates: %d across linear regression, decision trees, and random forests.", nrow(domain)),
  sprintf("- TruVaRImp evaluations: %d; additional verification fits: %d.",
    length(searched), nrow(domain) - length(searched)),
  sprintf("- Retained: %d models from %d model classes.", length(keep), length(unique(members$model_class))),
  sprintf("- Validation MSE: best %.6f; membership threshold %.6f (35%% relative tolerance).", min(losses), threshold),
  "- Disjoint partitions: 350 training rows, 175 validation rows, 175 PFI holdout rows.",
  sprintf("- PFI: %d permutations per feature, %d model-feature means, %d individual scores.",
    n_repeats, nrow(importance), nrow(scores)), "",
  "## Findings", "",
  "| Feature | Minimum mean PFI | Median mean PFI | Maximum mean PFI |",
  "|---|---:|---:|---:|",
  vapply(seq_len(nrow(summary)), function(i) sprintf("| %s | %.4f | %.4f | %.4f |",
    summary$feature[i], summary$minimum[i], summary$median[i], summary$maximum[i]), character(1)), "",
  "PFI is the increase in holdout MSE after permutation. All permutations use retained fits without retraining.",
  "The signal and proxy are correlated by construction. Ranges describe this finite set; they are not confidence intervals or population-risk guarantees.", "",
  "## Figures", "",
  "![Model selection](model-performance.png)", "", "![Importance cloud](pfi-cloud.png)", "",
  "![Model profiles](pfi-heatmap.png)", "", "![Feature ranks](pfi-ranks.png)", "",
  "![Importance versus loss](pfi-performance.png)", "", "![Search progress](search.png)", "",
  "Each figure is also available as a PDF with the same basename.", "",
  "## Reproduce and audit", "", "From the repository root, after installing cashomon, rpart, ranger and ggplot2:", "",
  "```sh", "Rscript inst/examples/offline-workflow.R", "```", "",
  "The CSV files contain every candidate, set member, permutation score, holdout prediction, simulated row, and permutation donor assignment.",
  "[Raw observations](simulated-data.csv) are also bundled in `inst/extdata/simulated-data.csv`; see the [data dictionary](../../inst/extdata/README.md).",
  "See `run-summary.csv` for seeds/settings and `session-info.txt` for package versions.",
  "`workflow.rds` retains fitted objects locally and is ignored by Git; rerun the script to recreate it.", "",
  "For the requested xplainfi implementation, install its dependencies and run `inst/examples/workflow.R`.",
  "Its outputs are written to the parent artifacts directory so backend provenance stays explicit.")
writeLines(report, file.path(output, "README.md"))
files <- list.files(output, full.names = TRUE)
files <- files[!basename(files) %in% c("workflow.rds", "checksums.csv")]
write_csv(data.frame(file = basename(files), md5 = unname(tools::md5sum(files))), "checksums.csv")
print(run)
print(summary)
cat("Generated results and figures in", output, "\n")
