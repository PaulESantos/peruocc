## Release Notes

This is a minor release (version 0.1.2) updating compatibility with 'rgbif' (>= 3.9.0) and introducing support for GBIF mediated downloads, quality filters, and explicit taxonomy keys.

* **rgbif 3.9.0 compatibility**:
  - Uses explicit `checklistKey` (resolving with Catalogue of Life / COL XR by default) to avoid mixing taxonomic backbones.
  - Adds configurable quality filters (`filtros_calidad_gbif_predeterminados()`) to exclude geospatial issues, fossils, and living specimens.
  - Adds mediated downloads for large polygon queries (`crear_descarga_gbif()`, `recuperar_descarga_gbif()`, `leer_descarga_gbif()`) supporting `SIMPLE_PARQUET` formats via 'arrow'.
  - Added 'arrow' to `Suggests`.
  - Added 'lifecycle' to `Imports` and marked download functions as experimental.

## Test environments
* local Windows 11 x64, R 4.6.1
* GitHub Actions: Windows, macOS, Ubuntu (release, devel)

## R CMD check results
There were 0 ERRORs, 0 WARNINGs, 0 NOTEs.

## Method References
There are no published references describing the methods in this package.
The package implements original integration and spatial validation workflows for official administrative boundary retrieval and biodiversity query standardization.
