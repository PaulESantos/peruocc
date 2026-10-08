# Filtros de calidad predeterminados para consultas GBIF

Devuelve una lista modificable para `filtros_calidad_gbif`. Los valores
predeterminados excluyen incidencias geoespaciales conocidas, registros
ausentes, fosiles y especimenes vivos. Los umbrales de incertidumbre y
de distancia a centroides son optativos porque esos campos pueden estar
vacios.

## Usage

``` r
filtros_calidad_gbif_predeterminados()
```

## Value

Lista de filtros compatible con `buscar_especies_*()` y
[`crear_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md).

## Examples

``` r
filtros <- filtros_calidad_gbif_predeterminados()
names(filtros)
#> [1] "has_geospatial_issue"               "occurrence_status"                 
#> [3] "excluir_basis_of_record"            "incertidumbre_max_m"               
#> [5] "permitir_incertidumbre_desconocida" "distancia_min_centroide_m"         
#> [7] "license"                           
```
