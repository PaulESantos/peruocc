# Realiza una busqueda combinada de especies en un distrito usando GBIF e iNaturalist

Realiza una busqueda combinada de especies en un distrito usando GBIF e
iNaturalist

## Usage

``` r
buscar_especies_distrito(
  distrito,
  departamento = NULL,
  provincia = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = TRUE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m
)
```

## Arguments

- distrito:

  Nombre del distrito (requerido).

- departamento:

  Nombre del departamento (opcional).

- provincia:

  Nombre de la provincia (opcional).

- nombre_cientifico:

  Nombre de la especie o grupo taxonomico a filtrar (opcional).

- grupo:

  Grupo taxonomico a filtrar: "flora", "fauna" o NULL.

- limite_por_api:

  Numero maximo de registros a solicitar por API (def: 500).

- guardar_resultados:

  Logico; si es TRUE guarda los resultados en data/ (def: TRUE).

- tolerancia_simplificacion:

  Tolerancia en metros para simplificar el poligono en GBIF (def: 100).

## Value

Una lista con el poligono del distrito, el dataframe de ocurrencias y
estadisticas de resumen.
