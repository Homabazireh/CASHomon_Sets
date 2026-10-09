# cashomon 0.1.0

* Load the `xplainfi` namespace when `cashomon` is attached (when installed), so
  the mlr3 column role it registers is in place before users build any Task.
  This fixes a `cashomon_pfi()` failure ("col_roles ... missing elements
  {'always_included'}") that occurred when `xplainfi` was only loaded lazily,
  after the task had already been created. Examples now also attach `xplainfi`
  before creating the task. The dependency-free `truvarimp()` search is
  unaffected when `xplainfi` is not installed.
* Bundle the 700-row raw simulated demonstration dataset in `inst/extdata/`
  with a data dictionary and loading instructions.
* Add reproducible simulated-data results and six PNG/PDF figures under
  `artifacts/direct-r-demo/`, explicitly labeled as a direct-R PFI fallback.
* Implement finite-domain TruVaRImp with GP conditioning, cost-weighted
  acquisition and explicit inside, outside and uncertain candidate sets.
* Add mlr3 candidate grids and verification of fitted CASHomon set members.
* Calculate xplainfi permutation feature importance for each retained model.
* Provide importance clouds, heatmaps, feature-rank and performance plots.
* Organize source files in a flat `R/` directory with roxygen documentation,
  a testthat edition 3 suite and a getting-started vignette.
* Add a reviewer report covering implementation, validation limits and
  reproduction steps.
* Clarify GitHub update commands and link the reviewer report from the README.
* Remove an accidentally created malformed README copy.
