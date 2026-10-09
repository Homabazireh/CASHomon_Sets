.onLoad <- function(libname, pkgname) {
  # Loading xplainfi registers an extra mlr3 column role ("always_included") in
  # mlr3's global reflections. A Task built *before* that registration keeps the
  # older col_roles set; xplainfi's resampling in cashomon_pfi() then fails
  # validating it ("missing elements {'always_included'}"). Trigger the
  # registration here, at package load, so it happens before users create any
  # Task (cashomon is attached first). Guarded and silent: when xplainfi is not
  # installed the dependency-free truvarimp() search is unaffected.
  tryCatch(requireNamespace("xplainfi", quietly = TRUE),
    error = function(e) FALSE)
  invisible()
}
