# Realiza una busqueda combinada de especies en una provincia usando GBIF e iNaturalist

Realiza una busqueda combinada de especies en una provincia usando GBIF
e iNaturalist

## Usage

``` r
buscar_especies_provincia(
  provincia,
  departamento = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m
)
```

## Arguments

- provincia:

  Nombre de la provincia (requerido).

- departamento:

  Nombre del departamento (opcional).

- nombre_cientifico:

  Nombre de la especie o grupo taxonomico a filtrar (opcional).

- grupo:

  Grupo taxonomico a filtrar: "flora", "fauna" o NULL.

- limite_por_api:

  Numero maximo de registros a solicitar por API (def: 500).

- guardar_resultados:

  Logico; si es TRUE guarda los resultados en processed/ (def: FALSE).

- tolerancia_simplificacion:

  Tolerancia en metros para simplificar el poligono en GBIF (def: 100).

## Value

Una lista con el poligono de la provincia, el dataframe de ocurrencias
consolidado y estadisticas de resumen.
