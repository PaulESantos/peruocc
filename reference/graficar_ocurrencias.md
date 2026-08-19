# Grafica el mapa de ocurrencias sobre el poligono de la unidad administrativa

Grafica el mapa de ocurrencias sobre el poligono de la unidad
administrativa

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

  Lista de resultados devuelta por buscar_especies_peru(),
  buscar_especies_distrito() o buscar_especies_provincia().

- color_por:

  Columna para clasificar los colores ("source" por defecto, o
  "kingdom").

- guardar_mapa:

  Logico; si es TRUE guarda el grafico en results/ como PNG (def:
  FALSE).

## Value

El objeto de grafico ggplot.
