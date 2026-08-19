# Exporta los resultados de una busqueda de biodiversidad a disco

Guarda los registros consolidados de ocurrencias en formatos CSV, capas
espaciales GeoJSON y un archivo de manifiesto JSON para trazabilidad y
reproducibilidad.

## Usage

``` r
exportar_resultados(
  resultado,
  dir_salida = NULL,
  prefijo = NULL,
  formatos = c("csv", "geojson", "manifiesto")
)
```

## Arguments

- resultado:

  Lista devuelta por
  [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md),
  [`buscar_especies_distrito()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_distrito.md)
  o
  [`buscar_especies_provincia()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_provincia.md).

- dir_salida:

  Directorio de destino donde se guardaran los archivos (por defecto el
  subdirectorio `processed/` de
  [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)).

- prefijo:

  Prefijo opcional para nombrar los archivos. Si es NULL, se genera
  automaticamente.

- formatos:

  Vector con los formatos a generar: "csv", "geojson", "manifiesto".

## Value

Una lista invisible con las rutas de los archivos generados.
