test_that("all four PFI views build and render", {
  skip_if_not_installed("ggplot2")
  fixture <- pfi_fixture()
  for (view in c("cloud", "heatmap", "ranks", "performance")) {
    plot <- plot_cashomon_pfi(fixture, view, permutation_intervals = TRUE)
    expect_s3_class(plot, "ggplot")
    expect_gt(length(ggplot2::ggplot_build(plot)$data), 0L)
    file <- tempfile(fileext = ".pdf")
    ggplot2::ggsave(file, plot, width = 10, height = 6)
    expect_gt(file.info(file)$size, 0)
    unlink(file)
  }
})

test_that("the search progress plot builds", {
  skip_if_not_installed("ggplot2")
  fit <- truvarimp(data.frame(x = 1:3), function(row) row$x, budget = 2)
  expect_s3_class(plot_cashomon_search(fit), "ggplot")
})
