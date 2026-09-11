## Resubmission Notes

This is a resubmission. In this version, we have addressed all comments provided by the CRAN reviewer (Konstanze Lauseker):

* **Single quotes in Description**: Ensured that only package, software, and API names are enclosed in single quotes (`'geoperu'`, `'iNaturalist'`). Removed single quotes from data standards and acronyms (`Darwin Core`, `GBIF`).
* **Avoid writing to user home filespace and getwd()**:
  - Functions no longer write to the user's home filespace, `getwd()`, or package directories by default.
  - Spatial boundaries and query caching now run purely in-memory (`.peruocc_mem_cache`) during the R session by default without writing checkpoint files to disk.
  - `peruocc_data_dir()` defaults to returning the active configuration (or `NULL`) without creating directories under `getwd()`.
  - `exportar_resultados()` and `graficar_ocurrencias(..., guardar_mapa = TRUE)` require an explicit destination path (e.g. `dir_salida = tempdir()`) or a previously configured directory.
  - All vignettes and examples now use `tempdir()` for file outputs.
* **Avoid package installation**:
  - Refactored `R/setup.R` (`verificar_y_configurar_entorno()`) to remove the `instalar` argument and all calls to `utils::install.packages()`. The function now strictly verifies dependency availability via `requireNamespace()`.
  - Removed all installation commands from vignettes and examples.

## Test environments
* local Windows 11, R 4.6.1
* GitHub Actions: Windows, macOS, Ubuntu (release, devel)

## R CMD check results
0 errors | 0 warnings | 0 notes

## Method References
There are no published references describing the methods in this package.
The package implements original integration and spatial validation workflows for official administrative boundary retrieval and biodiversity query standardization.
