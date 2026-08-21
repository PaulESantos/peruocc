# Busca ocurrencias en un distrito peruano

Atajo legible de
[`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md)
con `nivel = "distrito"`. Acepte los mismos filtros y devuelve la misma
estructura de resultado.

## Usage

``` r
buscar_especies_distrito(
  distrito,
  departamento = NULL,
  provincia = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
  ...
)
```

## Arguments

- distrito:

  Cadena no vacía con el nombre del distrito.

- departamento:

  `NULL` o departamento que contiene al distrito.

- provincia:

  `NULL` o provincia que contiene al distrito; úselo junto a
  `departamento` para resolver nombres repetidos.

- nombre_cientifico:

  `NULL` o nombre de taxón para filtrar resultados.

- grupo:

  `NULL`, `"flora"` o `"fauna"`.

- limite_por_api:

  Entero entre 1 y 10000, o `NULL`; consulte
  [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md)
  para sus límites y consecuencias.

- guardar_resultados:

  Lógico que exporta CSV, GeoJSON y manifiesto al finalizar cuando es
  `TRUE`.

- tolerancia_simplificacion:

  Tolerancia de simplificación para la llamada a GBIF, expresada en
  metros.

- ...:

  Controles avanzados reenviados a
  [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md):
  `estrategia_espacial`, `max_area_ha`, `cache_dir`, `reintentos` y
  `pausa_entre_lotes_s`.

## Value

Lista con límite, ocurrencias, resumen y parámetros. Consulte el valor
retornado por
[`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md).
