# Busca ocurrencias en un polígono personalizado

Consulta GBIF e iNaturalist sobre un límite aportado por el usuario. El
área se normaliza mediante
[`preparar_poligono_usuario()`](https://paulesantos.github.io/peruocc/reference/preparar_poligono_usuario.md),
se consulta por WKT o caja delimitadora y, finalmente, los puntos se
recortan contra la geometría exacta localmente. Soporta áreas de
estudio, buffers, ANP y polígonos de múltiples partes.

## Usage

``` r
buscar_especies_poligono(
  poligono,
  nombre = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
  estrategia_espacial = c("auto", "directa", "segmentada"),
  max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
  cache_dir = ruta_cache("consultas_ocurrencias"),
  reintentos = configuracion_predeterminada()$reintentos_api,
  pausa_entre_lotes_s = configuracion_predeterminada()$pausa_entre_lotes_s
)
```

## Arguments

- poligono:

  Objeto `sf`, `sfc` o `Spatial`, o ruta de longitud uno a un archivo
  `.shp`, `.geojson`, `.gpkg` o `.kml`. Debe tener geometría poligonal;
  los elementos múltiples se disuelven en un único límite.

- nombre:

  `NULL` o etiqueta de texto para identificar la consulta. Si es `NULL`,
  se usa el nombre del archivo o `"Poligono_Personalizado"`.

- nombre_cientifico:

  `NULL` o nombre de especie/grupo taxonómico. Se usa para filtrar ambas
  fuentes, aunque cada API puede resolver sinónimos de forma distinta.

- grupo:

  `NULL`, `"flora"` o `"fauna"`; filtra por Plantae o Animalia.

- limite_por_api:

  Entero entre 1 y 10000, o `NULL`. Es un máximo por API y tesela; no es
  el máximo global. `NULL` intenta recuperar todas las filas solamente
  si los límites técnicos de ambas APIs lo permiten.

- guardar_resultados:

  Lógico. Con `TRUE` exporta los resultados en la carpeta `processed/`
  configurada con
  [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md).

- tolerancia_simplificacion:

  Número no negativo, en metros, usado para acortar la geometría WKT de
  GBIF. El filtro espacial final usa siempre la geometría original.

- estrategia_espacial:

  Una de `"auto"`, `"segmentada"` o `"directa"`. `"auto"` equivale a
  `"segmentada"` y divide polígonos grandes; `"directa"` evita teselas y
  solo es aconsejable para áreas pequeñas.

- max_area_ha:

  Área positiva, en hectáreas, objetivo de cada tesela para estrategia
  segmentada. El valor 1000 equilibra tamaño de petición y número de
  llamadas; reduzca este valor ante errores por volumen.

- cache_dir:

  Directorio escribible para checkpoints de resultados por fuente/lote.
  Conservarlo permite reanudar una extracción interrumpida.

- reintentos:

  Entero positivo con el número máximo de reintentos de llamadas remotas
  transitorias.

- pausa_entre_lotes_s:

  Número no negativo de segundos de espera entre lotes. Aumentarlo es
  útil ante respuestas de límite de tasa.

## Value

Lista con `unidad_sf`, `ocurrencias`, `resumen` y `parametros`.
`resumen$fallos_lotes` indica si alguna fuente/lote no pudo completarse.

## Examples

``` r
coords <- matrix(c(-77.05, -12.10, -77.01, -12.10, -77.01, -12.05,
                   -77.05, -12.05, -77.05, -12.10), ncol = 2, byrow = TRUE)
zona <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
if (FALSE) { # \dontrun{
resultado <- buscar_especies_poligono(zona, nombre = "Zona de prueba",
                                       grupo = "flora", limite_por_api = 500)
} # }
```
