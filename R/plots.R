.theme_cashomon <- function() {
  ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 18, colour = "#152B3C"),
    plot.subtitle = ggplot2::element_text(colour = "#536878", margin = ggplot2::margin(b = 12)),
    plot.caption = ggplot2::element_text(colour = "#536878", hjust = 0),
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.y = ggplot2::element_blank(),
    legend.position = "bottom", legend.title = ggplot2::element_blank(),
    plot.background = ggplot2::element_rect(fill = "#FAFBFD", colour = NA),
    panel.background = ggplot2::element_rect(fill = "#FAFBFD", colour = NA),
    strip.text = ggplot2::element_text(face = "bold", colour = "#152B3C"),
    plot.margin = ggplot2::margin(16, 20, 12, 16))
}

.class_colors <- function(classes) {
  colors <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#332288")
  levels <- sort(unique(classes))
  if (length(levels) > length(colors)) colors <- grDevices::hcl.colors(length(levels), "Dark 3")
  stats::setNames(colors[seq_along(levels)], levels)
}

#' Visualize feature importance across the CASHomon set
#'
#' All views give each fitted configuration one observation, averaging its
#' permutations first. The cloud shows per-model points, the full empirical
#' min/max range and median; the heatmap shows model profiles; ranks shows
#' within-model ranks with average ties; performance relates PFI to validation
#' loss. Permutation intervals, when requested, are 5/95 percentiles, not CIs.
#' @param object Output of cashomon_pfi.
#' @param type One of cloud, heatmap, ranks or performance.
#' @param features Optional subset of features to display. Ranks remain ranks
#'   within the full set of features computed by cashomon_pfi.
#' @param permutation_intervals Show within-model permutation spread in cloud.
#' @return A customizable ggplot object; save with ggplot2::ggsave.
#' @export
plot_cashomon_pfi <- function(object, type = c("cloud", "heatmap", "ranks", "performance"),
                              features = NULL, permutation_intervals = FALSE) {
  .need("ggplot2")
  if (!inherits(object, "cashomon_pfi")) stop("Expected cashomon_pfi.", call. = FALSE)
  type <- match.arg(type)
  if (is.null(features)) features <- object$features
  if (!is.character(features) || !length(features) || anyNA(features) ||
      anyDuplicated(features) || !all(features %in% object$features))
    stop("features must select computed feature names.", call. = FALSE)
  if (!is.logical(permutation_intervals) || length(permutation_intervals) != 1L ||
      is.na(permutation_intervals)) stop("permutation_intervals must be TRUE or FALSE.", call. = FALSE)
  d <- object$importance[object$importance$feature %in% features, , drop = FALSE]
  summaries <- summarise_cashomon_pfi(object)
  summaries <- summaries[summaries$feature %in% features, , drop = FALSE]
  order <- summaries$feature[order(summaries$median)]
  d$feature <- factor(d$feature, levels = order)
  summaries$feature <- factor(summaries$feature, levels = order)
  palette <- .class_colors(d$model_class)
  subtitle <- paste(length(unique(d$model_id)), "retained models |",
                    length(unique(d$model_class)), "model classes |",
                    object$n_repeats, "permutations per feature")
  units <- paste0("PFI: increase in ", object$measure)
  caption <- "Each point or cell represents a fitted model. Model spread describes this finite candidate set."
  if (type == "cloud") {
    # Deterministic vertical offsets let intervals line up with their own points.
    ids <- sort(unique(d$model_id))
    offset <- if (length(ids) == 1L) 0 else seq(-0.23, 0.23, length.out = length(ids))
    d$position <- as.numeric(d$feature) + offset[match(d$model_id, ids)]
    p <- ggplot2::ggplot(d, ggplot2::aes(x = importance, y = position, colour = model_class)) +
      ggplot2::geom_vline(xintercept = 0, colour = "#9AAAB6", linetype = "dashed") +
      ggplot2::geom_segment(data = summaries,
        ggplot2::aes(x = minimum, xend = maximum, y = as.numeric(feature), yend = as.numeric(feature)),
        inherit.aes = FALSE, colour = "#CBD5DE", linewidth = 5, alpha = 0.6)
    if (permutation_intervals) {
      p <- p + ggplot2::geom_segment(ggplot2::aes(x = permutation_q05, xend = permutation_q95,
        yend = position), alpha = 0.23, linewidth = 0.6)
      caption <- paste(caption, "Thin lines: 5-95% permutation ranges, not confidence intervals.")
    }
    p <- p + ggplot2::geom_point(size = 2.3, alpha = 0.8) +
      ggplot2::geom_point(data = summaries,
        ggplot2::aes(x = median, y = as.numeric(feature)), inherit.aes = FALSE,
        shape = 23, fill = "white", colour = "#152B3C", size = 3) +
      ggplot2::scale_y_continuous(breaks = seq_along(order), labels = order) +
      ggplot2::scale_colour_manual(values = palette) +
      ggplot2::labs(title = "Many good models. Different explanations.",
        subtitle = subtitle, x = units, y = NULL,
        caption = paste("Bands: model min-max. Diamonds: median.", caption))
  } else if (type == "heatmap") {
    models <- unique(d[c("model_id", "model_class", "validation_loss")])
    models <- models[order(models$model_class, models$validation_loss, models$model_id), ]
    d$model_id <- factor(d$model_id, levels = rev(models$model_id))
    d$feature <- factor(d$feature, levels = rev(order))
    p <- ggplot2::ggplot(d, ggplot2::aes(x = feature, y = model_id, fill = importance)) +
      ggplot2::geom_tile(colour = "#FAFBFD", linewidth = 0.4) +
      ggplot2::facet_grid(model_class ~ ., scales = "free_y", space = "free_y") +
      ggplot2::scale_fill_gradient2(low = "#B35806", mid = "#F1F4F7", high = "#2166AC", midpoint = 0) +
      ggplot2::labs(title = "The explanation fingerprint of every model",
        subtitle = subtitle, x = NULL, y = NULL, fill = units,
        caption = paste("Within each class, models are ordered by validation loss.", caption)) +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
  } else if (type == "ranks") {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = rank, y = feature, colour = model_class)) +
      ggplot2::geom_boxplot(ggplot2::aes(group = feature), colour = "#CBD5DE",
        fill = "#E7EEF4", outlier.shape = NA, width = 0.45, orientation = "y") +
      ggplot2::geom_point(position = ggplot2::position_jitter(width = 0, height = 0.17, seed = 42),
        size = 2.3, alpha = 0.8) +
      ggplot2::scale_x_continuous(breaks = seq_along(object$features)) +
      ggplot2::scale_colour_manual(values = palette) +
      ggplot2::labs(title = "Do good models agree on the top features?",
        subtitle = subtitle, x = "Feature rank within each model (1 = most important)",
        y = NULL, caption = paste("Tied importances receive average ranks.", caption))
  } else {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = validation_loss, y = importance, colour = model_class)) +
      ggplot2::geom_hline(yintercept = 0, colour = "#9AAAB6", linetype = "dashed") +
      ggplot2::geom_vline(xintercept = object$threshold, colour = "#8B5E83", linetype = "dotted") +
      ggplot2::geom_point(size = 2.6, alpha = 0.8) +
      ggplot2::facet_wrap(~ feature, scales = "free_y") +
      ggplot2::scale_colour_manual(values = palette) +
      ggplot2::labs(title = "Similar performance, different feature reliance",
        subtitle = subtitle, x = paste0("Validation loss (", object$measure, ")"), y = units,
        caption = paste("Dotted line: CASHomon selection threshold.", caption))
  }
  p <- p + ggplot2::labs(caption = paste(strwrap(p$labels$caption, width = 105),
    collapse = "\n")) + .theme_cashomon()
  if (type == "heatmap") p <- p + ggplot2::theme(
    legend.title = ggplot2::element_text(colour = "#536878"))
  p
}

#' Plot progress of Algorithm 1
#'
#' Displays counts in L, H and U by objective evaluation, before empirical
#' verification of the surrogate classifications.
#'
#' @param object A truvarimp_result or cashomon_set.
#' @return A ggplot object showing counts in L, H and U by evaluation.
#' @export
plot_cashomon_search <- function(object) {
  .need("ggplot2")
  if (inherits(object, "cashomon_set")) object <- object$search
  if (!inherits(object, "truvarimp_result") || !nrow(object$trace))
    stop("Expected a search result with at least one evaluation.", call. = FALSE)
  d <- do.call(rbind, lapply(c("n_low", "n_high", "n_uncertain"), function(column) {
    data.frame(iteration = c(0, object$trace$iteration),
      count = c(if (column == "n_uncertain") nrow(object$domain) else 0, object$trace[[column]]),
      state = switch(column, n_low = "Inside (L)", n_high = "Outside (H)", n_uncertain = "Uncertain (U)"))
  }))
  ggplot2::ggplot(d, ggplot2::aes(x = iteration, y = count, colour = state)) +
    ggplot2::geom_step(linewidth = 1) + ggplot2::geom_point(size = 1.7) +
    ggplot2::scale_colour_manual(values = c("Inside (L)" = "#009E73", "Outside (H)" = "#D55E00",
      "Uncertain (U)" = "#0072B2")) +
    ggplot2::labs(title = "Finding the CASHomon set", subtitle = "TruVaRImp active search",
      x = "Objective evaluations", y = "Candidate configurations",
      caption = "Surrogate classifications from Algorithm 1; empirical membership is verified separately.") +
    .theme_cashomon()
}

utils::globalVariables(c("importance", "position", "model_class", "minimum", "maximum",
  "feature", "permutation_q05", "permutation_q95", "median", "model_id", "rank",
  "validation_loss", "iteration", "count", "state", "self", "super"))
