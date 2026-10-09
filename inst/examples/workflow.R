# Run after installing cashomon and its optional ML dependencies:
# Rscript inst/examples/workflow.R
library(cashomon)
library(mlr3)
library(mlr3learners)

set.seed(2603)
n <- 700L
signal <- rnorm(n)
data <- data.frame(signal = signal,
  proxy = signal + rnorm(n, sd = 0.25), modifier = runif(n, -1, 1),
  noise = rnorm(n))
data$target <- 3 * signal + 1.5 * data$modifier^2 + rnorm(n, sd = 0.8)
task <- as_task_regr(data, target = "target", id = "correlated_signal")
rows <- sample(task$row_ids)
train_rows <- rows[1:350]
validation_rows <- rows[351:525]
test_rows <- rows[526:700]

candidates <- cashomon_candidates(
  learners = list(Linear = lrn("regr.lm"), Tree = lrn("regr.rpart"),
                  Forest = lrn("regr.ranger", num.trees = 150, num.threads = 1)),
  grids = list(Tree = list(cp = c(0.0001, 0.003, 0.015), minsplit = c(10L, 25L)),
               Forest = list(mtry = c(1L, 2L, 4L), min.node.size = c(3L, 10L, 25L)))
)

models <- fit_cashomon(task, candidates, train_rows, validation_rows,
  epsilon_rel = 0.35, budget = 10, verify_all = TRUE, seed = 42)
# verify_all exhausts this small demonstration pool after active search; for a
# large pool use FALSE to verify only surrogate L plus already evaluated models.
print(models)
print(models$members)

pfi <- cashomon_pfi(models, test_rows, n_repeats = 30, seed = 42)
print(pfi)
print(summarise_cashomon_pfi(pfi))
dir.create("artifacts", showWarnings = FALSE)
utils::write.csv(models$archive, "artifacts/candidates.csv", row.names = FALSE)
utils::write.csv(pfi$importance, "artifacts/pfi-by-model.csv", row.names = FALSE)
utils::write.csv(pfi$scores, "artifacts/pfi-permutations.csv", row.names = FALSE)
saveRDS(list(models = models, pfi = pfi), "artifacts/workflow.rds")
for (view in c("cloud", "heatmap", "ranks", "performance")) {
  plot <- plot_cashomon_pfi(pfi, view)
  ggplot2::ggsave(file.path("artifacts", paste0("pfi-", view, ".png")),
                 plot, width = 10, height = 6, dpi = 180)
  ggplot2::ggsave(file.path("artifacts", paste0("pfi-", view, ".pdf")),
                 plot, width = 10, height = 6)
}
ggplot2::ggsave("artifacts/search.png", plot_cashomon_search(models),
               width = 9, height = 5, dpi = 180)
