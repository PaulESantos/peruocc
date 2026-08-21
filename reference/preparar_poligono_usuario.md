# Valida y normaliza un polígono aportado por el usuario

Acepta una geometría u archivo espacial, lo transforma a WGS84, corrige
topología cuando es posible y unifica múltiples elementos en un único
límite. Es la preparación previa que usa
[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md).

## Usage

``` r
preparar_poligono_usuario(poligono, nombre = NULL)
```

## Arguments

- poligono:

  Un objeto `sf`, `sfc` o `Spatial`, o una ruta de longitud uno a
  `.shp`, `.geojson`, `.gpkg` o `.kml`. Debe contener geometrías
  poligonales. Si no tiene CRS se asume EPSG:4326 y se emite una
  advertencia.

- nombre:

  `NULL` o una etiqueta de texto no vacía para resultados y
  exportaciones. Si `poligono` es una ruta y `nombre` es `NULL`, se usa
  el nombre del archivo sin extensión; para objetos espaciales se usa
  `"Poligono_Personalizado"`.

## Value

Un objeto `sf` válido de una fila en EPSG:4326, con las columnas
`unidad`, `distrito`, `provincia` y `departamento`. Las tres últimas se
rellenan con `NA` porque el límite no procede de una unidad
administrativa.

## Examples

``` r
coords <- matrix(c(-77.05, -12.10, -77.01, -12.10, -77.01, -12.05,
                   -77.05, -12.05, -77.05, -12.10), ncol = 2, byrow = TRUE)
zona <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
preparar_poligono_usuario(zona, nombre = "Zona de prueba")
#> Simple feature collection with 1 feature and 4 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -77.05 ymin: -12.1 xmax: -77.01 ymax: -12.05
#> Geodetic CRS:  WGS 84
#>                                x         unidad distrito provincia departamento
#> 1 POLYGON ((-77.05 -12.1, -77... Zona de prueba     <NA>      <NA>         <NA>
```
