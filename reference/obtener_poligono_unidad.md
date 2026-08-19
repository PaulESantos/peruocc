# Obtiene el poligono de una unidad administrativa (distrito o provincia)

Obtiene el poligono de una unidad administrativa (distrito o provincia)

## Usage

``` r
obtener_poligono_unidad(
  nombre,
  nivel = c("distrito", "provincia"),
  departamento = NULL,
  provincia = NULL
)
```

## Arguments

- nombre:

  Nombre de la unidad administrativa.

- nivel:

  Nivel administrativo: "distrito" o "provincia" (def: "distrito").

- departamento:

  Nombre del departamento (opcional).

- provincia:

  Nombre de la provincia (opcional, para nivel "distrito").

## Value

Objeto sf con la geometria de la unidad.
