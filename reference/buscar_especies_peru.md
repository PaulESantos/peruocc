# Realiza una busqueda combinada de especies en una unidad administrativa del Peru

Realiza una busqueda combinada de especies en una unidad administrativa
del Peru

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
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m
)
```

## Arguments

- nombre:

  Nombre de la unidad administrativa (distrito o provincia).

- nivel:

  Nivel administrativo: "distrito" o "provincia" (def: "distrito").

- departamento:

  Nombre del departamento (opcional).

- provincia:

  Nombre de la provincia (opcional, aplicable cuando nivel =
  "distrito").

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

Una lista con el poligono de la unidad, el dataframe de ocurrencias
consolidado y estadisticas de resumen.
