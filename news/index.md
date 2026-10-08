# Changelog

## peruocc 0.1.2

- Updated compatibility for ‘rgbif’ (\>= 3.9.0).
- `buscar_especies_*()` now uses a single explicit GBIF taxonomy
  (`checklistKey`), resolving group and scientific-name keys with
  Catalogue of Life (COL XR) by default to avoid mixing COL and legacy
  Backbone identifiers.
- `buscar_especies_*()` adds configurable GBIF quality filters
  ([`filtros_calidad_gbif_predeterminados()`](https://paulesantos.github.io/peruocc/reference/filtros_calidad_gbif_predeterminados.md))
  and requires an explicit opt-in for fuzzy or higher-rank taxonomic
  matches.
- Added
  [`crear_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md)
  to create citable, mediated GBIF downloads for large polygons, with
  `SIMPLE_PARQUET` as the default format.
  [`solicitar_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md)
  is retained as a deprecated alias.
- [`crear_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md)
  simplifies extensive polygons without replacing them by their bounding
  box, and requires an explicit output directory when waiting for the
  archive.
- Added
  [`recuperar_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/recuperar_descarga_gbif.md)
  to safely download an already-processed GBIF request and create the
  destination directory when needed.
- Added
  [`leer_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/leer_descarga_gbif.md)
  to open GBIF Parquet downloads lazily via ‘arrow’, ignoring empty
  fragments included in partitioned archives.
- Marked
  [`crear_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md),
  [`recuperar_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/recuperar_descarga_gbif.md),
  and
  [`leer_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/leer_descarga_gbif.md)
  as experimental using ‘lifecycle’.

## peruocc 0.1.1

CRAN release: 2026-10-06

- [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)
  now stores canonical paths after creating the requested directory,
  ensuring consistent behavior on macOS systems where equivalent paths
  may traverse symbolic links.

## peruocc 0.1.0

CRAN release: 2026-09-21

- Initial release to CRAN.
- Provides functions to query and standardize biodiversity occurrence
  records in Peru across administrative levels (districts and provinces)
  and user-defined polygons using ‘GBIF’ and ‘iNaturalist’.
- Integrates official administrative boundaries via ‘geoperu’.
- Exports standardized tabular data, spatial GeoJSON layers,
  publication-ready occurrence maps, and JSON reproducibility manifests.
