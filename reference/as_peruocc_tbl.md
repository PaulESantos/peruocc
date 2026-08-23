# Coerción a objeto tabular ligero (estilo tibble)

Convierte un `data.frame` u objeto compatible en una estructura tabular
con clase `c("peruocc_tbl", "tbl_df", "tbl", "data.frame")`, compatible
con el ecosistema tidyverse sin generar conflictos ni dependencias
pesadas.

## Usage

``` r
as_peruocc_tbl(x, ...)
```

## Arguments

- x:

  Un `data.frame`, lista o matriz a convertir.

- ...:

  Argumentos adicionales ignorados para compatibilidad.

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
