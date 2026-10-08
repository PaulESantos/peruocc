# peruocc 0.1.2

* Updated compatibility for 'rgbif' (>= 3.9.0).
* `buscar_especies_*()` now uses a single explicit GBIF taxonomy (`checklistKey`),
  resolving group and scientific-name keys with Catalogue of Life (COL XR) by
  default to avoid mixing COL and legacy Backbone identifiers.
* `buscar_especies_*()` adds configurable GBIF quality filters
  (`filtros_calidad_gbif_predeterminados()`) and requires an explicit opt-in for
  fuzzy or higher-rank taxonomic matches.
* Added `crear_descarga_gbif()` to create citable, mediated GBIF downloads for
  large polygons, with `SIMPLE_PARQUET` as the default format.
  `solicitar_descarga_gbif()` is retained as a deprecated alias.
* `crear_descarga_gbif()` simplifies extensive polygons without replacing them
  by their bounding box, and requires an explicit output directory when waiting
  for the archive.
* Added `recuperar_descarga_gbif()` to safely download an already-processed GBIF
  request and create the destination directory when needed.
* Added `leer_descarga_gbif()` to open GBIF Parquet downloads lazily via 'arrow',
  ignoring empty fragments included in partitioned archives.
* Marked `crear_descarga_gbif()`, `recuperar_descarga_gbif()`, and `leer_descarga_gbif()`
  as experimental using 'lifecycle'.

# peruocc 0.1.1

* `peruocc_data_dir()` now stores canonical paths after creating the requested
  directory, ensuring consistent behavior on macOS systems where equivalent
  paths may traverse symbolic links.

# peruocc 0.1.0

* Initial release to CRAN.
* Provides functions to query and standardize biodiversity occurrence records in Peru across administrative levels (districts and provinces) and user-defined polygons using 'GBIF' and 'iNaturalist'.
* Integrates official administrative boundaries via 'geoperu'.
* Exports standardized tabular data, spatial GeoJSON layers, publication-ready occurrence maps, and JSON reproducibility manifests.
