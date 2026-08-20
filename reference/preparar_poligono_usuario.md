# Prepara y estandariza un poligono espacial provisto por el usuario

Lee archivos espaciales (.shp, .geojson, .gpkg, .kml) o valida objetos
`sf`/`sfc`, asegurando que esten en proyeccion geografica WGS84
(EPSG:4326), con topologia valida y estructurados para consultas de
biodiversidad.

## Usage

``` r
preparar_poligono_usuario(poligono, nombre = NULL)
```

## Arguments

- poligono:

  Objeto sf/sfc o ruta a un archivo espacial en disco.

- nombre:

  Nombre o etiqueta descriptiva para el poligono (opcional).

## Value

Un objeto sf estandarizado en EPSG:4326 con atributos descriptivos.
