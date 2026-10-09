library(cashomon)
library(mlr3)
task <- as_task_classif(iris, target = "Species")
# Stratified train / validation / PFI split for this small example.
set.seed(42)
by_class <- split(task$row_ids, iris$Species)
parts <- lapply(by_class, sample)
train <- unlist(lapply(parts, function(x) x[1:25]), use.names = FALSE)
validation <- unlist(lapply(parts, function(x) x[26:37]), use.names = FALSE)
test <- unlist(lapply(parts, function(x) x[38:50]), use.names = FALSE)
pool <- cashomon_candidates(list(Tree = lrn("classif.rpart", predict_type = "prob")),
  list(Tree = list(cp = c(0.001, 0.01, 0.05), maxdepth = c(2L, 4L))))
models <- fit_cashomon(task, pool, train, validation, measure = msr("classif.logloss"),
  epsilon_abs = 0.1, epsilon_rel = 0, budget = 4, verify_all = TRUE)
pfi <- cashomon_pfi(models, test, n_repeats = 20)
print(plot_cashomon_pfi(pfi, "cloud"))
