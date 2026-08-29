# tibble_light.R
# Implementacion ligera de tibble sin dependencias externas pesadas.

#' Coerción a objeto tabular ligero (estilo tibble)
#'
#' Convierte un `data.frame` u objeto compatible en una estructura tabular
#' con clase `c("peruocc_tbl", "tbl_df", "tbl", "data.frame")`, compatible
#' con el ecosistema tidyverse sin generar conflictos ni dependencias pesadas.
#'
#' @param x Un `data.frame`, lista o matriz a convertir, o un objeto `peruocc_tbl`.
#' @param i,j Índices de filas y columnas para extracción o indexación tabular.
#' @param drop Lógico. Si es `TRUE`, simplifica a vector cuando el resultado es unidimensional.
#' @param n Entero positivo con el número de filas a mostrar en consola.
#' @param width Entero con el ancho de pantalla en caracteres; si es `NULL`, toma `getOption("width")`.
#' @param ... Argumentos adicionales pasados a otros métodos.
#' @return Un objeto tabular con clase `c("peruocc_tbl", "tbl_df", "tbl", "data.frame")`.
#' @examples
#' df <- data.frame(a = 1:5, b = letters[1:5])
#' tbl <- as_peruocc_tbl(df)
#' class(tbl)
#' @export
as_peruocc_tbl <- function(x, ...) {
  UseMethod("as_peruocc_tbl")
}

#' @rdname as_peruocc_tbl
#' @export
as_peruocc_tbl.data.frame <- function(x, ...) {
  if (inherits(x, "peruocc_tbl") && inherits(x, "tbl_df")) {
    return(x)
  }
  attr(x, "row.names") <- .set_row_names(nrow(x))
  class(x) <- unique(c("peruocc_tbl", "tbl_df", "tbl", "data.frame"))
  x
}

#' @rdname as_peruocc_tbl
#' @export
as_peruocc_tbl.default <- function(x, ...) {
  as_peruocc_tbl.data.frame(as.data.frame(x, stringsAsFactors = FALSE))
}

# Alias interno para compatibilidad
as_tibble <- as_peruocc_tbl

#' @rdname as_peruocc_tbl
#' @export
`[.peruocc_tbl` <- function(x, i, j, drop = FALSE) {
  if (missing(i) && missing(j)) {
    return(x)
  }
  
  res <- if (nargs() < 3L || missing(j)) {
    NextMethod("[")
  } else {
    NextMethod("[", drop = drop)
  }
  
  if (is.data.frame(res)) {
    attr(res, "row.names") <- .set_row_names(nrow(res))
    class(res) <- unique(c("peruocc_tbl", "tbl_df", "tbl", "data.frame"))
  }
  res
}

# Helper para abreviar tipos de datos al estilo tibble
abreviar_tipo <- function(col) {
  if (is.character(col)) "chr"
  else if (is.integer(col)) "int"
  else if (is.numeric(col)) "dbl"
  else if (is.logical(col)) "lgl"
  else if (inherits(col, "Date")) "date"
  else if (inherits(col, "POSIXt")) "dttm"
  else if (is.factor(col)) "fct"
  else if (is.list(col)) "list"
  else substring(class(col)[1], 1, 4)
}

# Helper para formatear celdas individuales
formatear_celda <- function(val, tipo, max_caracteres = 15) {
  if (is.null(val) || length(val) == 0) return("")
  if (is.na(val)) return("NA")
  if (tipo == "dbl") {
    return(format(val, digits = 3, nsmall = 1, trim = TRUE))
  }
  if (tipo == "int") {
    return(as.character(val))
  }
  if (tipo == "lgl") {
    return(if (isTRUE(val)) "TRUE" else "FALSE")
  }
  if (tipo == "date") {
    return(as.character(val))
  }
  if (tipo == "dttm") {
    return(substr(format(val, "%Y-%m-%d"), 1, 10))
  }
  if (tipo == "list") {
    return("<list>")
  }
  txt <- as.character(val)
  if (nchar(txt) > max_caracteres) {
    if (max_caracteres <= 3) {
      substr(txt, 1, max_caracteres)
    } else {
      paste0(substr(txt, 1, max_caracteres - 1), "\u2026")
    }
  } else {
    txt
  }
}

# Helper de alineacion y relleno de texto
rellenar_celda <- function(texto, ancho, alineacion = "left") {
  len <- nchar(texto)
  if (len >= ancho) return(texto)
  espacios <- strrep(" ", ancho - len)
  if (alineacion == "right") paste0(espacios, texto) else paste0(texto, espacios)
}

#' @rdname as_peruocc_tbl
#' @export
print.peruocc_tbl <- function(x, n = 10L, width = NULL, ...) {
  # Si pillar o tibble estan activos en el search path, usar su formateador nativo
  if ("package:tibble" %in% search() || "package:pillar" %in% search()) {
    return(NextMethod())
  }
  
  filas_total <- nrow(x)
  cols_total <- ncol(x)
  n_mostrar <- min(filas_total, as.integer(n))
  ancho_consola <- if (!is.null(width)) as.integer(width) else getOption("width", 80)
  
  cat(cli::col_grey(sprintf("# A tibble: %s \u00d7 %s\n", format(filas_total, big.mark = ","), cols_total)))
  
  if (filas_total == 0L || cols_total == 0L) {
    return(invisible(x))
  }
  
  # Extraer datos de muestra y calcular tipos
  sub_df <- as.data.frame(x[seq_len(n_mostrar), , drop = FALSE])
  tipos <- vapply(sub_df, abreviar_tipo, character(1))
  tipos_etiqueta <- sprintf("<%s>", tipos)
  
  # Calcular ancho óptimo por columna para maximizar variables visibles
  anchos_col <- integer(cols_total)
  for (j in seq_len(cols_total)) {
    nombre_len <- nchar(names(sub_df)[j])
    tipo_len <- nchar(tipos_etiqueta[j])
    ancho_base <- max(nombre_len, tipo_len, 4)
    
    t_j <- tipos[j]
    if (t_j %in% c("dbl", "int", "lgl", "date", "dttm")) {
      vals_raw <- vapply(sub_df[[j]], function(v) formatear_celda(v, t_j, 30), character(1))
      max_val_len <- if (length(vals_raw) > 0) max(nchar(vals_raw)) else 0
      anchos_col[j] <- max(ancho_base, max_val_len)
    } else {
      # Columnas de texto: se ajustan de forma compacta al ancho de la cabecera
      anchos_col[j] <- max(ancho_base, 8)
    }
  }
  
  # Formatear celdas truncando según el ancho asignado
  celdas_mat <- matrix("", nrow = n_mostrar, ncol = cols_total)
  for (j in seq_len(cols_total)) {
    t_j <- tipos[j]
    w_j <- anchos_col[j]
    for (i in seq_len(n_mostrar)) {
      celdas_mat[i, j] <- formatear_celda(sub_df[i, j], t_j, max_caracteres = w_j)
    }
  }
  
  # Seleccionar columnas visibles segun ancho de pantalla
  rn_digitos <- max(1, nchar(as.character(n_mostrar)))
  ancho_prefijo_fila <- rn_digitos + 1 # digitos + espacio
  
  cols_visibles <- integer()
  ancho_acumulado <- ancho_prefijo_fila
  
  for (j in seq_len(cols_total)) {
    ancho_necesario <- anchos_col[j] + 1 # ancho + 1 espacio de separacion
    if (length(cols_visibles) == 0 || (ancho_acumulado + ancho_necesario <= ancho_consola)) {
      cols_visibles <- c(cols_visibles, j)
      ancho_acumulado <- ancho_acumulado + ancho_necesario
    } else {
      break
    }
  }
  
  # Imprimir cabecera de nombres
  prefijo_vacio <- strrep(" ", ancho_prefijo_fila)
  linea_nombres <- paste(vapply(cols_visibles, function(j) {
    align <- if (tipos[j] %in% c("dbl", "int")) "right" else "left"
    rellenar_celda(names(sub_df)[j], anchos_col[j], align)
  }, character(1)), collapse = " ")
  cat(paste0(prefijo_vacio, linea_nombres, "\n"))
  
  # Imprimir cabecera de tipos en gris
  linea_tipos <- paste(vapply(cols_visibles, function(j) {
    align <- if (tipos[j] %in% c("dbl", "int")) "right" else "left"
    rellenar_celda(tipos_etiqueta[j], anchos_col[j], align)
  }, character(1)), collapse = " ")
  cat(cli::col_grey(paste0(prefijo_vacio, linea_tipos, "\n")))
  
  # Imprimir filas de datos
  for (i in seq_len(n_mostrar)) {
    prefijo_num <- cli::col_grey(sprintf(paste0("%", rn_digitos, "d "), i))
    linea_valores <- paste(vapply(cols_visibles, function(j) {
      align <- if (tipos[j] %in% c("dbl", "int")) "right" else "left"
      val_str <- celdas_mat[i, j]
      rellenar_celda(val_str, anchos_col[j], align)
    }, character(1)), collapse = " ")
    cat(paste0(prefijo_num, linea_valores, "\n"))
  }
  
  # Pie de pagina: filas restantes
  filas_restantes <- filas_total - n_mostrar
  if (filas_restantes > 0L) {
    cat(cli::col_grey(sprintf("# \u2139 %s fila%s m\u00e1s\n",
                              format(filas_restantes, big.mark = ","),
                              if (filas_restantes == 1) "" else "s")))
  }
  
  # Pie de pagina: variables ocultas (multilinea completa sin truncar)
  cols_ocultas <- setdiff(seq_len(cols_total), cols_visibles)
  if (length(cols_ocultas) > 0L) {
    items_ocultos <- sprintf("%s <%s>", names(sub_df)[cols_ocultas], tipos[cols_ocultas])
    prefijo <- sprintf("# \u2139 %d variable%s m\u00e1s: ",
                       length(cols_ocultas),
                       if (length(cols_ocultas) == 1) "" else "s")
    
    ancho_limite <- max(30, ancho_consola)
    lineas_envueltas <- character()
    linea_actual <- prefijo
    
    for (idx in seq_along(items_ocultos)) {
      item <- items_ocultos[idx]
      separador <- if (idx == 1L) "" else ", "
      candidato <- paste0(linea_actual, separador, item)
      
      if (nchar(candidato) <= ancho_limite || linea_actual == prefijo) {
        linea_actual <- candidato
      } else {
        lineas_envueltas <- c(lineas_envueltas, paste0(linea_actual, ","))
        linea_actual <- paste0("#   ", item)
      }
    }
    if (nzchar(linea_actual)) {
      lineas_envueltas <- c(lineas_envueltas, linea_actual)
    }
    
    for (l in lineas_envueltas) {
      cat(cli::col_grey(paste0(l, "\n")))
    }
  }
  
  # Sugerencia de visualizacion
  if (filas_restantes > 0L) {
    cat(cli::col_grey("# \u2139 Use `print(n = ...)` para ver m\u00e1s filas\n"))
  }
  
  invisible(x)
}
