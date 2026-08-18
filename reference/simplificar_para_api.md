# Simplifica un poligono sf o genera su bounding box si es muy complejo para cumplir con el limite de longitud de caracteres de WKT.

Simplifica un poligono sf o genera su bounding box si es muy complejo
para cumplir con el limite de longitud de caracteres de WKT.

## Usage

``` r
simplificar_para_api(sf_obj, max_char = 1500, tolerancia_inicial_metros = 100)
```

## Arguments

- sf_obj:

  Objeto sf.

- max_char:

  Limite de caracteres WKT (def: 1500).

- tolerancia_inicial_metros:

  Tolerancia inicial en metros para la simplificacion.

## Value

Objeto sf simplificado (o su bbox) apto para consulta.
