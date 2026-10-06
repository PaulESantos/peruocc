# peruocc 0.1.1

* `peruocc_data_dir()` now stores canonical paths after creating the requested
  directory, ensuring consistent behavior on macOS systems where equivalent
  paths may traverse symbolic links.

# peruocc 0.1.0

* Initial release to CRAN.
* Provides functions to query and standardize biodiversity occurrence records in Peru across administrative levels (districts and provinces) and user-defined polygons using 'GBIF' and 'iNaturalist'.
* Integrates official administrative boundaries via 'geoperu'.
* Exports standardized tabular data, spatial GeoJSON layers, publication-ready occurrence maps, and JSON reproducibility manifests.
