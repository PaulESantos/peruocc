# Simplifica un poligono de tipo sf usando proyecciones UTM

Simplifica un poligono de tipo sf usando proyecciones UTM

## Usage

``` r
simplificar_poligono(sf_obj, tolerancia_metros = 100)
```

## Arguments

- sf_obj:

  Objeto sf con la geometria.

- tolerancia_metros:

  Tolerancia de simplificacion en metros (def: 100 metros).

## Value

Objeto sf simplificado en EPSG:4326.
