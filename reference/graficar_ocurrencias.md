# Grafica el mapa de ocurrencias sobre el poligono del distrito

Grafica el mapa de ocurrencias sobre el poligono del distrito

## Usage

``` r
graficar_ocurrencias(
  resultado_lista,
  color_por = "source",
  guardar_mapa = TRUE
)
```

## Arguments

- resultado_lista:

  Lista de resultados devuelta por buscar_especies_distrito().

- color_por:

  Columna para clasificar los colores ("source" por defecto, o
  "kingdom").

- guardar_mapa:

  Logico; si es TRUE guarda el grafico en data/ como PNG (def: TRUE).

## Value

El objeto de grafico ggplot.
