# Busca ocurrencias de especies en iNaturalist dentro de un poligono de distrito

Busca ocurrencias de especies en iNaturalist dentro de un poligono de
distrito

## Usage

``` r
buscar_inat_por_poligono(
  poligono_sf,
  query = NULL,
  taxon_name = NULL,
  grupo = NULL,
  calidad = "research",
  limite = 500
)
```

## Arguments

- poligono_sf:

  Objeto sf que representa el distrito (EPSG:4326).

- query:

  Texto libre de busqueda (opcional).

- taxon_name:

  Nombre de la especie o grupo taxonomico (opcional).

- grupo:

  Grupo taxonomico: "flora", "fauna" o NULL.

- calidad:

  Grado de calidad: "research" (por defecto), "casual" o NULL (ambos).

- limite:

  Numero maximo de registros a recuperar (max. 10000 para get_inat_obs).

## Value

Un dataframe estandarizado con los registros encontrados que caen dentro
del poligono.
