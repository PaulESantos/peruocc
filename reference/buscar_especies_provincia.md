# Busca ocurrencias en una provincia peruana

Atajo de
[`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md)
con `nivel = "provincia"`. Con la estrategia predeterminada procesa los
distritos de forma independiente y consolida al final, una opción más
recuperable que consultar la provincia disuelta en una sola petición.

## Usage

``` r
buscar_especies_provincia(
  provincia,
  departamento = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
  ...
)
```

## Arguments

- provincia:

  Cadena no vacía con el nombre de la provincia.

- departamento:

  `NULL` o el departamento que contiene la provincia. Es necesario
  cuando el nombre es ambiguo.

- nombre_cientifico:

  `NULL` o nombre de taxón para filtrar.

- grupo:

  `NULL`, `"flora"` o `"fauna"`.

- limite_por_api:

  Entero entre 1 y 10000, o `NULL`; se aplica a cada fuente y lote.

- guardar_resultados:

  Lógico; si es `TRUE` exporta los resultados finales.

- tolerancia_simplificacion:

  Tolerancia para simplificación de WKT de GBIF, medida en metros.

- ...:

  Controles avanzados reenviados a
  [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md).
  Destacan `max_area_ha` para ajustar las teselas y `cache_dir` para
  reanudar.

## Value

Lista con límite provincial disuelto, ocurrencias consolidadas, resumen
de lotes y parámetros de la ejecución.
