# Coerción a objeto tabular ligero (estilo tibble)

Convierte un `data.frame` u objeto compatible en una estructura tabular
con clase `c("peruocc_tbl", "tbl_df", "tbl", "data.frame")`, compatible
con el ecosistema tidyverse sin generar conflictos ni dependencias
pesadas.

## Usage

``` r
as_peruocc_tbl(x, ...)

# S3 method for class 'data.frame'
as_peruocc_tbl(x, ...)

# Default S3 method
as_peruocc_tbl(x, ...)

# S3 method for class 'peruocc_tbl'
x[i, j, drop = FALSE]

# S3 method for class 'peruocc_tbl'
print(x, n = 10L, width = NULL, ...)
```

## Arguments

- x:

  Un `data.frame`, lista o matriz a convertir, o un objeto
  `peruocc_tbl`.

- ...:

  Argumentos adicionales pasados a otros métodos.

- i, j:

  Índices de filas y columnas para extracción o indexación tabular.

- drop:

  Lógico. Si es `TRUE`, simplifica a vector cuando el resultado es
  unidimensional.

- n:

  Entero positivo con el número de filas a mostrar en consola.

- width:

  Entero con el ancho de pantalla en caracteres; si es `NULL`, toma
  `getOption("width")`.

## Value

Un objeto tabular con clase
`c("peruocc_tbl", "tbl_df", "tbl", "data.frame")`.

## Examples

``` r
df <- data.frame(a = 1:5, b = letters[1:5])
tbl <- as_peruocc_tbl(df)
class(tbl)
#> [1] "peruocc_tbl" "tbl_df"      "tbl"         "data.frame" 
```
