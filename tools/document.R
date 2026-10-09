# Run from the package root: Rscript tools/document.R
if (!requireNamespace("roxygen2", quietly = TRUE)) {
  stop('Install documentation tooling first: install.packages("roxygen2")')
}

# The initial files were bootstrapped from roxygen comments in an offline
# environment. Hand them over to roxygen2; it otherwise preserves files without
# its own generated-file marker. Never remove handwritten documentation.
outputs <- c("NAMESPACE", list.files("man", pattern = "\\.Rd$", full.names = TRUE))
for (file in outputs) {
  if (file.exists(file) && grepl("Generated from R/.*offline documentation bootstrap",
      readLines(file, n = 1L, warn = FALSE))) unlink(file)
}
roxygen2::roxygenise(roclets = c("rd", "namespace"))
