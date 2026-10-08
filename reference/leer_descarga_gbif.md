# Abre archivos Parquet de una descarga GBIF

**\[experimental\]**

Abre de forma perezosa los archivos Parquet extraidos de una descarga
GBIF. Los fragmentos vacios se excluyen automaticamente, pues GBIF puede
incluirlos en descargas particionadas.

## Usage

``` r
leer_descarga_gbif(ruta)
```

## Arguments

- ruta:

  Directorio extraido de una descarga `SIMPLE_PARQUET` o un vector de
  archivos Parquet.

## Value

Un
[`arrow::Dataset`](https://arrow.apache.org/docs/r/reference/Dataset.html).

## Examples

``` r
if (FALSE) { # \dontrun{
registros <- leer_descarga_gbif("datos/gbif/parquet")
} # }
```
