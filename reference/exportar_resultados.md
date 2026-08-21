# Exporta un resultado de búsqueda a formatos interoperables

Escribe las ocurrencias consolidadas como tabla CSV, capa GeoJSON y/o un
manifiesto JSON de reproducibilidad. El manifiesto registra parámetros,
geometría, versiones de paquetes y las rutas creadas. No se genera
ningún archivo si `resultado$ocurrencias` no contiene filas.

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

  Lista producida por una función `buscar_especies_*()`. Debe contener
  al menos `ocurrencias`, `resumen`, `parametros` y `unidad_sf`.

- dir_salida:

  Ruta de destino. Si es `NULL`, usa `processed/` dentro de
  [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md).
  Se crea junto con sus padres si no existe.

- prefijo:

  Cadena opcional para el identificador de archivos. Con `NULL` se forma
  uno con fecha UTC, nivel, unidad y grupo. No incluya extensión: esta
  función añade `.csv`, `.geojson` o `.json`.

- formatos:

  Vector no vacío formado por `"csv"`, `"geojson"` y/o `"manifiesto"`.
  El CSV mantiene todas las filas; el GeoJSON omite filas sin longitud o
  latitud finitas.

## Value

Invisiblemente, una lista nombrada con las rutas creadas. Los nombres
posibles son `csv`, `geojson` y `manifiesto`.

## Examples

``` r
if (FALSE) { # \dontrun{
resultado <- buscar_especies_distrito("Miraflores", departamento = "Lima")
exportar_resultados(resultado, formatos = c("csv", "manifiesto"))
} # }
```
