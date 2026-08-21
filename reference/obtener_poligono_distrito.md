# Obtiene el límite oficial de un distrito peruano

Descarga o recupera del caché la capa distrital de `geoperu`, localiza
la unidad solicitada sin distinguir mayúsculas ni tildes y devuelve una
geometría válida en WGS84. Es la forma recomendada de inspeccionar un
límite antes de una búsqueda o de resolver ambigüedades administrativas.

## Usage

``` r
obtener_poligono_distrito(distrito, departamento = NULL, provincia = NULL)
```

## Arguments

- distrito:

  Cadena no vacía con el nombre oficial o usual del distrito. La
  coincidencia ignora tildes y mayúsculas; no se aceptan códigos UBIGEO.

- departamento:

  `NULL` o cadena con uno de los 25 departamentos del Perú. Recomendado
  para nombres de distrito repetidos y para evitar descargar la capa
  nacional completa.

- provincia:

  `NULL` o cadena con la provincia que contiene el distrito. Se combina
  con `departamento` para desambiguar. Si persisten varias
  coincidencias, la función muestra alternativas y se detiene.

## Value

Un objeto `sf` de una fila, EPSG:4326, con columnas `departamento`,
`provincia`, `distrito`, `capital` (cuando esté disponible) y geometría.

## Examples

``` r
if (FALSE) { # \dontrun{
miraflores <- obtener_poligono_distrito(
  distrito = "Miraflores", departamento = "Lima", provincia = "Lima"
)
} # }
```
