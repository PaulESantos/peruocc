# Obtiene un límite administrativo mediante una interfaz única

Despacha a
[`obtener_poligono_distrito()`](https://paulesantos.github.io/peruocc/reference/obtener_poligono_distrito.md)
o
[`obtener_poligono_provincia()`](https://paulesantos.github.io/peruocc/reference/obtener_poligono_provincia.md)
según `nivel`. Facilita crear funciones genéricas cuando el nivel de
consulta se elige en tiempo de ejecución.

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

  Cadena no vacía. Es el nombre del distrito cuando `nivel = "distrito"`
  o el de la provincia cuando `nivel = "provincia"`.

- nivel:

  Uno de `"distrito"` o `"provincia"`. Si se suministra más de un valor,
  se usa el primero mediante
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).

- departamento:

  `NULL` o nombre del departamento para limitar la búsqueda y resolver
  homónimos.

- provincia:

  `NULL` o nombre de provincia; solo se usa con `nivel = "distrito"`.

## Value

Un objeto `sf` en EPSG:4326. Para provincias la geometría está disuelta;
para distritos contiene una fila de la capa oficial.

## Examples

``` r
if (FALSE) { # \dontrun{
limite <- obtener_poligono_unidad("Tarapoto", nivel = "distrito",
                                  departamento = "San Martin")
} # }
```
