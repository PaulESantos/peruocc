# Busca ocurrencias de especies en GBIF dentro de un poligono de distrito o provincia

Busca ocurrencias de especies en GBIF dentro de un poligono de distrito
o provincia

## Usage

``` r
buscar_gbif_por_poligono(
  poligono_sf,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite = 500,
  tolerancia_simplificacion = 100
)
```

## Arguments

- poligono_sf:

  Objeto sf que representa la unidad espacial (EPSG:4326).

- nombre_cientifico:

  Nombre de la especie o grupo taxonomico (opcional).

- grupo:

  Grupo taxonomico: "flora", "fauna" o NULL.

- limite:

  Numero maximo de registros a recuperar (max. 100000 para occ_search).

- tolerancia_simplificacion:

  Tolerancia de simplificacion en metros (def: 100 metros).

## Value

Un dataframe estandarizado con los registros encontrados.
