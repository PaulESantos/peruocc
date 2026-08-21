# Busca ocurrencias de GBIF dentro de un polígono

Función de bajo nivel usada por las búsquedas integradas. Convierte el
límite a WKT, lo simplifica si es necesario para la API de GBIF y luego
vuelve a filtrar localmente con el polígono exacto. Para uso habitual
prefiera las funciones `buscar_especies_*()`, que además integran
iNaturalist y manejan lotes/checkpoints.

## Usage

``` r
buscar_gbif_por_poligono(
  poligono_sf,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite = 500,
  tolerancia_simplificacion = 100,
  reintentos = configuracion_predeterminada()$reintentos_api
)
```

## Arguments

- poligono_sf:

  Objeto `sf` poligonal, preferiblemente en EPSG:4326. Debe contener una
  geometría válida; atributos administrativos son opcionales y se copian
  al resultado cuando existen.

- nombre_cientifico:

  `NULL` o cadena con un taxón. Se intenta resolver mediante el backbone
  de GBIF; si no hay coincidencia, se aplica como texto libre en
  `scientificName`.

- grupo:

  `NULL`, `"flora"` o `"fauna"`, que se traduce a los reinos Plantae y
  Animalia, respectivamente.

- limite:

  Entero positivo de hasta 100000, o `NULL`. Con entero solicita hasta
  ese número de filas. Con `NULL` consulta primero el conteo y solo
  continúa si no supera el límite de
  [`rgbif::occ_search()`](https://docs.ropensci.org/rgbif/reference/occ_search.html)
  (100000).

- tolerancia_simplificacion:

  Número no negativo de metros. Es la tolerancia inicial de
  simplificación del WKT; se incrementa internamente cuando la geometría
  aún es demasiado extensa.

- reintentos:

  Entero positivo con intentos máximos para operaciones remotas
  transitorias, incluido el resolver taxonómico.

## Value

`data.frame` con el esquema estándar de ocurrencias. Los atributos
`api_total` y `api_complete` describen la respuesta de GBIF.
