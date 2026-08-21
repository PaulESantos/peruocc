# Grafica ocurrencias sobre su área de consulta

Construye un mapa `ggplot2` con el polígono consultado y los registros
que quedaron después del filtro espacial exacto. Es apropiada para
inspección exploratoria y control de calidad de coordenadas, no para
cartografía final.

## Usage

``` r
graficar_ocurrencias(
  resultado_lista,
  color_por = "source",
  guardar_mapa = FALSE
)
```

## Arguments

- resultado_lista:

  Lista devuelta por
  [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md),
  [`buscar_especies_distrito()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_distrito.md),
  [`buscar_especies_provincia()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_provincia.md)
  o
  [`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md).
  Debe contener `unidad_sf`, `ocurrencias` y `resumen`.

- color_por:

  Cadena con la columna usada para colorear puntos. Los valores
  admitidos son `"source"` (GBIF/iNaturalist, predeterminado) y
  `"kingdom"` (Plantae/Animalia cuando está disponible).

- guardar_mapa:

  Lógico de longitud uno. Si es `TRUE`, además devuelve el gráfico y lo
  guarda como PNG en `results/` dentro de
  [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md).

## Value

Un objeto de clase `ggplot`. Puede añadirse capas o temas de `ggplot2`
antes de imprimirlo.

## Examples

``` r
if (FALSE) { # \dontrun{
resultado <- buscar_especies_distrito("Miraflores", departamento = "Lima")
graficar_ocurrencias(resultado, color_por = "source")
} # }
```
