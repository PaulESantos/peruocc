# Obtiene el límite consolidado de una provincia peruana

Recupera los distritos de la provincia desde `geoperu` y disuelve sus
geometrías en una sola entidad válida. Para descargar ocurrencias
provinciales use
[`buscar_especies_provincia()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_provincia.md),
que internamente conserva los distritos separados para hacer consultas
más resilientes.

## Usage

``` r
obtener_poligono_provincia(provincia, departamento = NULL)
```

## Arguments

- provincia:

  Cadena no vacía con el nombre de la provincia. La búsqueda no
  distingue tildes ni mayúsculas.

- departamento:

  `NULL` o cadena con el departamento que contiene la provincia. Es
  obligatorio cuando el nombre existe en más de un departamento.

## Value

Un objeto `sf` de una fila en EPSG:4326, con `departamento`,
`provincia`, `distrito` (`NA`) y la geometría disuelta.

## Examples

``` r
if (FALSE) { # \dontrun{
urubamba <- obtener_poligono_provincia("Urubamba", departamento = "Cusco")
} # }
```
