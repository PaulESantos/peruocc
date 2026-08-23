# Busca y consolida ocurrencias en una unidad administrativa del Perú

Es la función general de consulta. Obtiene el límite oficial, consulta
GBIF e iNaturalist, valida localmente que cada coordenada esté dentro
del polígono y unifica las columnas en un esquema común. Para áreas
extensas puede dividir la consulta en lotes con checkpoint, evitando que
un fallo obligue a empezar de nuevo.

## Usage

``` r
buscar_especies_peru(
  nombre,
  nivel = c("distrito", "provincia"),
  departamento = NULL,
  provincia = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
  estrategia_espacial = c("auto", "directa", "segmentada"),
  max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
  max_lotes = configuracion_predeterminada()$max_lotes_espaciales,
  cache_dir = ruta_cache("consultas_ocurrencias"),
  reintentos = configuracion_predeterminada()$reintentos_api,
  pausa_entre_lotes_s = configuracion_predeterminada()$pausa_entre_lotes_s
)
```

## Arguments

- nombre:

  Cadena no vacía con el distrito o provincia solicitado, según `nivel`.
  La coincidencia ignora tildes y mayúsculas.

- nivel:

  Uno de `"distrito"` o `"provincia"`; determina cómo se interpreta
  `nombre`. Las provincias se resuelven con sus distritos componentes
  cuando se usa la estrategia segmentada.

- departamento:

  `NULL` o cadena con el departamento. Es muy recomendable para resolver
  nombres repetidos y reduce la descarga de límites.

- provincia:

  `NULL` o cadena con la provincia. Solo aplica a búsquedas distritales
  y ayuda a desambiguar homónimos.

- nombre_cientifico:

  `NULL` o cadena con un taxón, por ejemplo `"Panthera onca"`. GBIF
  intenta resolverlo en su backbone taxonómico; iNaturalist lo usa como
  filtro por nombre.

- grupo:

  `NULL`, `"flora"` o `"fauna"` (sin distinguir mayúsculas). Se traduce
  a Plantae o Animalia. Puede combinarse con `nombre_cientifico`.

- limite_por_api:

  Entero entre 1 y 10000, o `NULL`. Es el máximo por fuente y lote, no
  el máximo final consolidado. `NULL` solicita descarga completa solo
  cuando cada API informa un conteo dentro de su capacidad; puede ser
  lento y detenerse para consultas demasiado grandes.

- guardar_resultados:

  Lógico. Si es `TRUE`, ejecuta
  [`exportar_resultados()`](https://paulesantos.github.io/peruocc/reference/exportar_resultados.md)
  al final. No sobrescribe resultados previos porque genera un
  identificador temporal nuevo.

- tolerancia_simplificacion:

  Distancia en metros para simplificar WKT en GBIF si supera el límite
  de longitud de la API.

- estrategia_espacial:

  Estrategia de particionamiento (`"auto"`, `"directa"` o
  `"segmentada"`). Con `"auto"`, las provincias se particionan por sus
  distritos y los distritos extensos se dividen en macro-bloques
  adaptativos.

- max_area_ha:

  Límite de área en hectáreas por lote para teselación cuando se usa
  `estrategia_espacial = "segmentada"`.

- max_lotes:

  Número máximo de macro-bloques espaciales generados por unidad
  geográfica para evitar saturar las cuotas de las APIs.

- cache_dir:

  Directorio para guardar checkpoints `.rds` por lote y fuente.

- reintentos:

  Entero positivo con el número de intentos para llamadas API.

- pausa_entre_lotes_s:

  Pausa en segundos entre lotes consecutivos.

## Value

Objeto con clase `peruocc_resultado` (lista con límite `unidad_sf`,
tibble de `ocurrencias`, `resumen` estadístico y `parametros`).

## Details

La deduplicación usa `source` y `sourceRecordID`; un mismo registro
procedente de GBIF e iNaturalist se mantiene, porque son fuentes
distintas. Los checkpoints se escriben tras terminar cada fuente/lote.
Revise `resultado$resumen$fallos_lotes` antes de interpretar una
descarga como completa.

## Examples

``` r
if (FALSE) { # \dontrun{
resultado <- buscar_especies_peru(
  nombre = "Tambopata", nivel = "provincia", departamento = "Madre de Dios",
  grupo = "fauna", limite_por_api = 1000, max_area_ha = 1000
)
head(resultado$ocurrencias)
} # }
```
