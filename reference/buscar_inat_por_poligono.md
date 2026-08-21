# Busca observaciones de iNaturalist dentro de un polígono

Función de bajo nivel para iNaturalist. La API recibe la caja
delimitadora, porque no admite el polígono completo en esta interfaz; el
paquete convierte las observaciones a `sf` y descarta localmente los
puntos fuera del límite exacto. Para una búsqueda multifuente use
`buscar_especies_*()`.

## Usage

``` r
buscar_inat_por_poligono(
  poligono_sf,
  query = NULL,
  taxon_name = NULL,
  grupo = NULL,
  calidad = "research",
  limite = 500,
  reintentos = configuracion_predeterminada()$reintentos_api
)
```

## Arguments

- poligono_sf:

  Objeto `sf` poligonal en EPSG:4326, o transformable a ese CRS. Sus
  atributos administrativos se conservan en la salida si existen.

- query:

  `NULL` o texto libre que iNaturalist usará como búsqueda general.
  Puede combinarse con `taxon_name`, aunque filtros muy restrictivos
  pueden devolver cero observaciones.

- taxon_name:

  `NULL` o nombre de taxón reconocido por iNaturalist, como
  `"Panthera onca"` o `"Plantae"`.

- grupo:

  `NULL`, `"flora"` o `"fauna"`. Solo se usa para establecer el reino
  cuando no se proporciona `taxon_name`.

- calidad:

  `"research"` (predeterminado), `"casual"` o `NULL`. `NULL` no envía
  filtro de calidad; cualquier otro texto se reenvía a la API.

- limite:

  Entero positivo de hasta 10000, o `NULL`. `NULL` solicita el conteo
  previo y solo continúa cuando iNaturalist reporta 10000 o menos.

- reintentos:

  Entero positivo con el máximo de intentos ante fallos de red
  transitorios.

## Value

`data.frame` estandarizado con las observaciones dentro del polígono.
Incluye los atributos `api_total` y `api_complete` cuando están
disponibles.
