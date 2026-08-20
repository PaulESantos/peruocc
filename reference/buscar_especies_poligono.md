# Realiza una busqueda combinada de especies en un poligono personalizado provisto por el usuario

Consulta registros de biodiversidad en GBIF e iNaturalist utilizando una
delimitacion espacial personalizada (archivo Shapefile, GeoJSON, GPKG,
KML o un objeto `sf`).

## Usage

``` r
buscar_especies_poligono(
  poligono,
  nombre = NULL,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite_por_api = configuracion_predeterminada()$limite_por_api,
  guardar_resultados = FALSE,
  tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m
)
```

## Arguments

- poligono:

  Objeto espacial (`sf` / `sfc`) o ruta a un archivo espacial en disco
  (`.shp`, `.geojson`, `.gpkg`, `.kml`).

- nombre:

  Nombre o etiqueta descriptiva para el poligono (opcional; por defecto
  el nombre del archivo o "Poligono_Personalizado").

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
