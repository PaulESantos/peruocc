# spatial_utils.R
# Funciones auxiliares para el procesamiento espacial de poligonos de distritos y provincias de Peru.

# Funcion interna para normalizar cadenas de texto (quitar tildes, mayusculas, etc.)
normalizar_texto <- function(texto) {
  if (is.null(texto)) return(NULL)
  texto <- toupper(texto)
  # Reemplazar caracteres especiales y acentos en espanol
  texto <- chartr("\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1", "AEIOUDN", texto)
  # Quitar puntuaciones y caracteres no alfanumericos (mantener espacios)
  texto <- gsub("[^A-Z0-9 ]", "", texto)
  texto <- trimws(texto)
  return(texto)
}

# Listado oficial de departamentos en geoperu
departamentos_oficiales <- function() {
  c("AMAZONAS", "ANCASH", "APURIMAC", "AREQUIPA", "AYACUCHO", 
    "CAJAMARCA", "CALLAO", "CUSCO", "HUANCAVELICA", "HUANUCO", 
    "ICA", "JUNIN", "LA LIBERTAD", "LAMBAYEQUE", "LIMA", 
    "LORETO", "MADRE DE DIOS", "MOQUEGUA", "PASCO", "PIURA", 
    "PUNO", "SAN MARTIN", "TACNA", "TUMBES", "UCAYALI")
}

# Helper interno para cargar geometrias departamentales con cache
cargar_mapa_departamental <- function(departamento = NULL) {
  loadNamespace("sf")
  deps_oficiales <- departamentos_oficiales()
  departamento_norm <- normalizar_texto(departamento)
  
  if (!is.null(departamento_norm)) {
    deps_norm <- sapply(deps_oficiales, normalizar_texto)
    indice_dep <- which(deps_norm == departamento_norm)
    
    if (length(indice_dep) == 0) {
      cli::cli_abort("El departamento {.val {departamento}} no es v\u00e1lido en el Per\u00fa.")
    }
    
    dep_oficial <- deps_oficiales[indice_dep]
    dep_clean <- gsub(" ", "_", tolower(departamento_norm))
    rds_path <- ruta_cache(sprintf("distritos_%s.rds", dep_clean))
    
    mapa <- NULL
    if (file.exists(rds_path)) {
      mapa <- tryCatch(readRDS(rds_path), error = function(e) NULL)
      if (is.null(mapa) || !inherits(mapa, "sf")) {
        unlink(rds_path)
        mapa <- NULL
      } else {
        cli::cli_alert_info("Cargando l\u00edmites de {.strong {dep_oficial}} desde el cach\u00e9 local...")
      }
    }
    
    if (is.null(mapa)) {
      cli::cli_alert_info("Descargando l\u00edmites de {.strong {dep_oficial}} v\u00eda {.pkg geoperu}...")
      mapa <- tryCatch({
        ejecutar_con_reintentos(function() {
          res <- geoperu::get_geo_peru(geography = dep_oficial, level = "dep", simplified = FALSE, showProgress = FALSE)
          if (is.null(res) || !inherits(res, c("sf", "sfc", "data.frame"))) {
            stop("geoperu retorno un objeto vacio o nulo (posible tiempo de espera agotado)")
          }
          if (!inherits(res, "sf")) res <- sf::st_as_sf(res)
          res
        }, reintentos = 3L, etiqueta = "geoperu", pausa_inicial_s = 1)
      }, error = function(e) {
        cli::cli_abort("No se pudieron descargar los l\u00edmites de {.strong {dep_oficial}} desde {.pkg geoperu}: {e$message}")
      })
      if (!is.null(mapa) && inherits(mapa, "sf")) {
        saveRDS(mapa, rds_path)
      }
    }
    if (is.null(mapa) || !inherits(mapa, "sf")) {
      cli::cli_abort("No se pudo cargar la capa espacial para {.strong {dep_oficial}}.")
    }
    return(mapa)
  }
  
  # Si no se especifica departamento, buscar primero en cache
  dir_c <- ruta_cache()
  archivos_cache <- list.files(dir_c, pattern = "^distritos_.*\\.rds$", full.names = TRUE)
  archivos_cache <- archivos_cache[!grepl("distritos_peru_completo.rds$", archivos_cache)]
  
  if (length(archivos_cache) > 0) {
    cli::cli_alert_info("Cargando datos disponibles desde cach\u00e9 local...")
    lista_mapas <- lapply(archivos_cache, readRDS)
    mapa_acumulado <- do.call(rbind, lista_mapas)
    if (!inherits(mapa_acumulado, "sf")) mapa_acumulado <- sf::st_as_sf(mapa_acumulado)
    return(mapa_acumulado)
  }
  
  rds_completo <- ruta_cache("distritos_peru_completo.rds")
  if (file.exists(rds_completo)) {
    cli::cli_alert_info("Cargando base de datos completa desde cach\u00e9 local...")
    mapa <- readRDS(rds_completo)
    if (!inherits(mapa, "sf")) mapa <- sf::st_as_sf(mapa)
    return(mapa)
  }
  
  cli::cli_alert_info("Departamento no especificado. Descargando l\u00edmites distritales del Per\u00fa v\u00eda {.pkg geoperu}...")
  lista_todos <- list()
  for (dep in deps_oficiales) {
    dep_clean <- gsub(" ", "_", tolower(normalizar_texto(dep)))
    rds_path <- ruta_cache(sprintf("distritos_%s.rds", dep_clean))
    
    if (file.exists(rds_path)) {
      lista_todos[[dep]] <- readRDS(rds_path)
    } else {
      cli::cli_alert_info("Descargando departamento: {.strong {dep}}...")
      dep_sf <- tryCatch({
        geoperu::get_geo_peru(geography = dep, level = "dep", simplified = FALSE, showProgress = FALSE)
      }, error = function(e) {
        cli::cli_alert_danger("Error al descargar {.strong {dep}}: {e$message}")
        NULL
      })
      if (!is.null(dep_sf)) {
        saveRDS(dep_sf, rds_path)
        lista_todos[[dep]] <- dep_sf
      }
    }
  }
  mapa <- do.call(rbind, lista_todos)
  saveRDS(mapa, rds_completo)
  cli::cli_alert_success("Cach\u00e9 local completo creado con \u00e9xito.")
  if (!inherits(mapa, "sf")) mapa <- sf::st_as_sf(mapa)
  return(mapa)
}

#' Obtiene el límite oficial de un distrito peruano
#'
#' Descarga o recupera del caché la capa distrital de `geoperu`, localiza la
#' unidad solicitada sin distinguir mayúsculas ni tildes y devuelve una
#' geometría válida en WGS84. Es la forma recomendada de inspeccionar un límite
#' antes de una búsqueda o de resolver ambigüedades administrativas.
#'
#' @param distrito Cadena no vacía con el nombre oficial o usual del distrito.
#'   La coincidencia ignora tildes y mayúsculas; no se aceptan códigos UBIGEO.
#' @param departamento `NULL` o cadena con uno de los 25 departamentos del Perú.
#'   Recomendado para nombres de distrito repetidos y para evitar descargar la
#'   capa nacional completa.
#' @param provincia `NULL` o cadena con la provincia que contiene el distrito.
#'   Se combina con `departamento` para desambiguar. Si persisten varias
#'   coincidencias, la función muestra alternativas y se detiene.
#' @return Un objeto `sf` de una fila, EPSG:4326, con columnas `departamento`,
#'   `provincia`, `distrito`, `capital` (cuando esté disponible) y geometría.
#' @examples
#' \dontrun{
#' miraflores <- obtener_poligono_distrito(
#'   distrito = "Miraflores", departamento = "Lima", provincia = "Lima"
#' )
#' }
#' @export
obtener_poligono_distrito <- function(distrito, departamento = NULL, provincia = NULL) {
  loadNamespace("sf")
  if (missing(distrito) || is.null(distrito)) {
    cli::cli_abort("Debe proporcionar el nombre de un distrito en {.arg distrito}.")
  }
  
  distrito_norm <- normalizar_texto(distrito)
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  distritos_mapa_norm <- sapply(mapa$distrito, normalizar_texto)
  provincias_mapa_norm <- sapply(mapa$provincia, normalizar_texto)
  departamentos_mapa_norm <- sapply(mapa$departamento, normalizar_texto)
  
  idx <- which(distritos_mapa_norm == distrito_norm)
  
  # Si no hubo coincidencia y buscamos en cache parcial, descargar completo
  if (length(idx) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    distritos_mapa_norm <- sapply(mapa_completo$distrito, normalizar_texto)
    provincias_mapa_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    departamentos_mapa_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    idx <- which(distritos_mapa_norm == distrito_norm)
    mapa <- mapa_completo
  }
  
  if (length(idx) == 0) {
    sugerencias <- unique(utils::head(mapa$distrito[agrep(distrito_norm, distritos_mapa_norm, max.distance = 0.1)], 5))
    if (length(sugerencias) > 0) {
      cli::cli_abort(c(
        "x" = "No se encontr\u00f3 el distrito {.val {distrito}}.",
        "i" = "Quiz\u00e1s quiso decir: {.val {sugerencias}}"
      ))
    } else {
      cli::cli_abort("No se encontr\u00f3 el distrito {.val {distrito}}.")
    }
  }
  
  if (!is.null(provincia_norm)) {
    idx <- idx[provincias_mapa_norm[idx] == provincia_norm]
  }
  
  if (!is.null(departamento_norm)) {
    idx <- idx[departamentos_mapa_norm[idx] == departamento_norm]
  }
  
  if (length(idx) > 1) {
    detalles <- sprintf("Departamento: %s | Provincia: %s | Distrito: %s", 
                        mapa$departamento[idx], 
                        mapa$provincia[idx], 
                        mapa$distrito[idx])
    cli::cli_abort(c(
      "x" = "Ambig\u00fcedad detectada: se encontraron m\u00faltiples distritos con el nombre {.val {distrito}}:",
      stats::setNames(detalles, rep("*", length(detalles))),
      "i" = "Especifique el par\u00e1metro {.arg departamento} o {.arg provincia} para afinar la b\u00fasqueda."
    ))
  }
  
  if (length(idx) == 0) {
    cli::cli_abort("No se encontr\u00f3 el distrito {.val {distrito}} con los filtros especificados.")
  }
  
  col_geom <- attr(mapa, "sf_column")
  geoms <- mapa[[col_geom]][idx]
  if (!inherits(geoms, "sfc")) {
    geoms <- sf::st_sfc(geoms, crs = sf::st_crs(mapa))
  }
  
  coincidencias <- sf::st_sf(
    departamento = mapa$departamento[idx],
    provincia = mapa$provincia[idx],
    distrito = mapa$distrito[idx],
    capital = if ("capital" %in% names(mapa)) mapa$capital[idx] else NA_character_,
    geometry = geoms,
    crs = sf::st_crs(mapa)
  )
  
  coincidencias <- sf::st_make_valid(coincidencias)
  coincidencias <- asegurar_orientacion_antihoraria(coincidencias)
  
  return(coincidencias)
}

#' Obtiene el límite oficial de una provincia peruana
#'
#' Recupera los distritos de la provincia desde `geoperu` y disuelve sus
#' geometrías en una sola entidad válida. Para descargar ocurrencias provinciales
#' use [buscar_especies_provincia()], que internamente conserva los distritos
#' separados para hacer consultas más resilientes.
#'
#' @param provincia Cadena no vacía con el nombre de la provincia. La búsqueda
#'   no distingue tildes ni mayúsculas.
#' @param departamento `NULL` o cadena con el departamento que contiene la
#'   provincia. Es obligatorio cuando el nombre existe en más de un departamento.
#' @return Un objeto `sf` de una fila en EPSG:4326, con `departamento`,
#'   `provincia`, `distrito` (`NA`) y la geometría disuelta.
#' @examples
#' \dontrun{
#' urubamba <- obtener_poligono_provincia("Urubamba", departamento = "Cusco")
#' }
#' @export
obtener_poligono_provincia <- function(provincia, departamento = NULL) {
  loadNamespace("sf")
  if (missing(provincia) || is.null(provincia)) {
    cli::cli_abort("Debe proporcionar el nombre de una provincia en {.arg provincia}.")
  }
  
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  provincias_mapa_norm <- sapply(mapa$provincia, normalizar_texto)
  departamentos_mapa_norm <- sapply(mapa$departamento, normalizar_texto)
  
  idx <- which(provincias_mapa_norm == provincia_norm)
  
  if (length(idx) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    provincias_mapa_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    departamentos_mapa_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    idx <- which(provincias_mapa_norm == provincia_norm)
    mapa <- mapa_completo
  }
  
  if (length(idx) == 0) {
    sugerencias <- unique(utils::head(mapa$provincia[agrep(provincia_norm, provincias_mapa_norm, max.distance = 0.1)], 5))
    if (length(sugerencias) > 0) {
      cli::cli_abort(c(
        "x" = "No se encontr\u00f3 la provincia {.val {provincia}}.",
        "i" = "Quiz\u00e1s quiso decir: {.val {sugerencias}}"
      ))
    } else {
      cli::cli_abort("No se encontr\u00f3 la provincia {.val {provincia}}.")
    }
  }
  
  if (!is.null(departamento_norm)) {
    idx <- idx[departamentos_mapa_norm[idx] == departamento_norm]
  }
  
  deps_encontrados <- unique(mapa$departamento[idx])
  if (length(deps_encontrados) > 1) {
    detalles <- sprintf("Departamento: %s | Provincia: %s", deps_encontrados, provincia)
    cli::cli_abort(c(
      "x" = "Ambig\u00fcedad detectada: se encontraron provincias con el nombre {.val {provincia}} en m\u00faltiples departamentos:",
      stats::setNames(detalles, rep("*", length(detalles))),
      "i" = "Especifique el par\u00e1metro {.arg departamento} para afinar la b\u00fasqueda."
    ))
  }
  
  col_geom <- attr(mapa, "sf_column")
  geoms <- mapa[[col_geom]][idx]
  if (!inherits(geoms, "sfc")) {
    geoms <- sf::st_sfc(geoms, crs = sf::st_crs(mapa))
  }
  
  coincidencias <- sf::st_sf(
    departamento = mapa$departamento[idx],
    provincia = mapa$provincia[idx],
    distrito = mapa$distrito[idx],
    geometry = geoms,
    crs = sf::st_crs(mapa)
  )
  
  dep_nombre <- coincidencias$departamento[1]
  prov_nombre <- coincidencias$provincia[1]
  
  geometria_union <- sf::st_union(sf::st_geometry(coincidencias))
  
  provincia_sf <- sf::st_sf(
    departamento = dep_nombre,
    provincia = prov_nombre,
    distrito = NA_character_,
    geometry = geometria_union,
    crs = sf::st_crs(coincidencias)
  )
  
  provincia_sf <- sf::st_make_valid(provincia_sf)
  provincia_sf <- asegurar_orientacion_antihoraria(provincia_sf)
  
  return(provincia_sf)
}

# Devuelve los distritos que integran una provincia sin disolver sus geometrías.
# Se usa internamente para distribuir una consulta grande en unidades recuperables.
obtener_distritos_provincia <- function(provincia, departamento = NULL) {
  provincia_sf <- obtener_poligono_provincia(provincia, departamento)
  mapa <- cargar_mapa_departamental(departamento = provincia_sf$departamento[1])
  if (attr(mapa, "sf_column") != "geometry") {
    sf::st_geometry(mapa) <- "geometry"
  }
  idx <- normalizar_texto(mapa$provincia) == normalizar_texto(provincia_sf$provincia[1])
  distritos <- mapa[idx, ]
  distritos <- sf::st_make_valid(distritos)
  distritos <- asegurar_orientacion_antihoraria(distritos)
  distritos
}

# Divide una geometría en teselas o macro-bloques de área acotada usando una proyección UTM.
# La teselación se realiza en metros y se devuelve nuevamente en EPSG:4326.
dividir_poligono_por_area <- function(poligono_sf,
                                      max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
                                      max_lotes = configuracion_predeterminada()$max_lotes_espaciales) {
  if (!inherits(poligono_sf, "sf")) cli::cli_abort("{.arg poligono_sf} debe ser un objeto {.cls sf}.")
  if (!is.numeric(max_area_ha) || length(max_area_ha) != 1L || is.na(max_area_ha) || max_area_ha <= 0) {
    cli::cli_abort("{.arg max_area_ha} debe ser un n\u00famero positivo.")
  }
  if (!is.null(max_lotes) && (!is.numeric(max_lotes) || length(max_lotes) != 1L || is.na(max_lotes) || max_lotes < 1)) {
    cli::cli_abort("{.arg max_lotes} debe ser un n\u00famero entero positivo o NULL.")
  }

  poligono_sf <- sf::st_make_valid(poligono_sf)
  poligono_sf <- sf::st_transform(poligono_sf, 4326)
  
  if (attr(poligono_sf, "sf_column") != "geometry") {
    sf::st_geometry(poligono_sf) <- "geometry"
  }
  cols_atributos <- setdiff(names(poligono_sf), c("geometry", "tile_id"))

  centroide <- sf::st_coordinates(sf::st_centroid(sf::st_union(poligono_sf)))[1, ]
  zona_utm <- max(1, min(60, floor((centroide[1] + 180) / 6) + 1))
  epsg_utm <- if (centroide[2] < 0) 32700 + zona_utm else 32600 + zona_utm
  poligono_utm <- sf::st_transform(poligono_sf, epsg_utm)
  area_ha <- as.numeric(sf::st_area(sf::st_union(poligono_utm))) / 10000

  if (area_ha <= max_area_ha) {
    poligono_sf$tile_id <- 1L
    cols_ordenadas <- c(cols_atributos, "tile_id", "geometry")
    return(poligono_sf[, cols_ordenadas])
  }

  # Calculo de macro-bloques adaptativos:
  # El área de cada lote se ajusta para que el número total estimado de lotes no sobrepase max_lotes
  area_lote_ha <- if (!is.null(max_lotes)) max(max_area_ha, area_ha / max_lotes) else max_area_ha
  lado_m <- sqrt(area_lote_ha * 10000)

  grilla <- sf::st_make_grid(sf::st_union(poligono_utm), cellsize = lado_m, square = TRUE)
  grilla <- grilla[lengths(sf::st_intersects(grilla, sf::st_union(poligono_utm))) > 0]
  partes_geom <- sf::st_intersection(grilla, sf::st_geometry(poligono_utm))
  partes_geom <- partes_geom[!sf::st_is_empty(partes_geom)]
  if (any(sf::st_geometry_type(partes_geom) == "GEOMETRYCOLLECTION")) {
    partes_geom <- sf::st_collection_extract(partes_geom, "POLYGON")
  }
  partes_geom <- sf::st_transform(partes_geom, 4326)

  df_base <- as.data.frame(poligono_sf)[1, cols_atributos, drop = FALSE]
  if (nrow(df_base) == 0 || length(cols_atributos) == 0) {
    df_rep <- data.frame(row.names = seq_along(partes_geom))
  } else {
    df_rep <- df_base[rep(1, length(partes_geom)), , drop = FALSE]
    rownames(df_rep) <- NULL
  }
  df_rep$tile_id <- seq_along(partes_geom)
  df_rep$geometry <- partes_geom

  partes_sf <- sf::st_as_sf(df_rep, sf_column_name = "geometry", crs = 4326)
  cols_ordenadas <- c(cols_atributos, "tile_id", "geometry")
  partes_sf[, cols_ordenadas]
}

#' Obtiene un límite administrativo mediante una interfaz única
#'
#' Despacha a [obtener_poligono_distrito()] o [obtener_poligono_provincia()]
#' según `nivel`. Facilita crear funciones genéricas cuando el nivel de consulta
#' se elige en tiempo de ejecución.
#'
#' @param nombre Cadena no vacía. Es el nombre del distrito cuando
#'   `nivel = "distrito"` o el de la provincia cuando `nivel = "provincia"`.
#' @param nivel Uno de `"distrito"` o `"provincia"`. Si se suministra más de
#'   un valor, se usa el primero mediante `match.arg()`.
#' @param departamento `NULL` o nombre del departamento para limitar la búsqueda
#'   y resolver homónimos.
#' @param provincia `NULL` o nombre de provincia; solo se usa con
#'   `nivel = "distrito"`.
#' @return Un objeto `sf` en EPSG:4326. Para provincias la geometría está
#'   disuelta; para distritos contiene una fila de la capa oficial.
#' @examples
#' \dontrun{
#' limite <- obtener_poligono_unidad("Tarapoto", nivel = "distrito",
#'                                   departamento = "San Martin")
#' }
#' @export
obtener_poligono_unidad <- function(nombre, nivel = c("distrito", "provincia"), departamento = NULL, provincia = NULL) {
  nivel <- match.arg(nivel)
  if (nivel == "distrito") {
    obtener_poligono_distrito(distrito = nombre, departamento = departamento, provincia = provincia)
  } else {
    obtener_poligono_provincia(provincia = nombre, departamento = departamento)
  }
}

#' Corrige la orientacion de un poligono sf para que el anillo exterior sea CCW
#' y los anillos interiores (huecos) sean CW.
#'
#' @param poly Objeto de tipo polygon de sf (lista de matrices).
#' @return Objeto de tipo polygon corregido.
corregir_poligono_ccw <- function(poly) {
  nuevo_poly <- list()
  for (j in seq_along(poly)) {
    ring <- poly[[j]]
    n <- nrow(ring)
    if (n >= 4) {
      x <- ring[, 1]
      y <- ring[, 2]
      # Formula de Shoelace para area con signo
      area <- sum(x[1:(n-1)] * y[2:n] - x[2:n] * y[1:(n-1)])
      
      # Anillo exterior (j == 1): Debe ser CCW (area > 0)
      # Anillos interiores/huecos (j > 1): Deben ser CW (area < 0)
      if (j == 1 && area < 0) {
        ring <- ring[n:1, ]
      } else if (j > 1 && area > 0) {
        ring <- ring[n:1, ]
      }
    }
    nuevo_poly[[j]] <- ring
  }
  return(sf::st_polygon(nuevo_poly))
}

#' Asegura que todas las geometrias de un objeto sf tengan orientacion antihoraria (CCW)
#'
#' @param sf_obj Objeto sf.
#' @return Objeto sf con orientaciones corregidas.
asegurar_orientacion_antihoraria <- function(sf_obj) {
  geom <- sf::st_geometry(sf_obj)
  for (i in seq_along(geom)) {
    feature <- geom[[i]]
    if (inherits(feature, "POLYGON")) {
      geom[[i]] <- corregir_poligono_ccw(feature)
    } else if (inherits(feature, "MULTIPOLYGON")) {
      geom[[i]] <- sf::st_multipolygon(lapply(feature, corregir_poligono_ccw))
    }
  }
  sf::st_geometry(sf_obj) <- geom
  return(sf_obj)
}

#' Simplifica un poligono sf o genera su bounding box si es muy complejo
#' para cumplir con el limite de longitud de caracteres de WKT.
#'
#' @param sf_obj Objeto sf.
#' @param max_char Limite de caracteres WKT (def: 1500).
#' @param tolerancia_inicial_metros Tolerancia inicial en metros para la simplificacion.
#' @return Objeto sf simplificado (o su bbox) apto para consulta.
simplificar_para_api <- function(sf_obj, max_char = 1500, tolerancia_inicial_metros = 100) {
  geom <- sf::st_geometry(sf_obj)
  wkt <- sf::st_as_text(geom[[1]])
  
  if (nchar(wkt) <= max_char) {
    return(sf_obj)
  }
  
  # Intentar simplificar progresivamente en UTM
  tol_metros <- tolerancia_inicial_metros
  sf_simp <- sf_obj
  for (i in 1:6) {
    sf_simp <- simplificar_poligono(sf_obj, tolerancia_metros = tol_metros)
    geom_simp <- sf::st_geometry(sf_simp)
    wkt_simp <- sf::st_as_text(geom_simp[[1]])
    
    if (nchar(wkt_simp) <= max_char) {
      cli::cli_alert_success("Pol\u00edgono simplificado con \u00e9xito a tolerancia de {tol_metros} metros (WKT: {nchar(wkt_simp)} caracteres).")
      return(sf_simp)
    }
    
    tol_metros <- tol_metros * 3
  }
  
  # Si sigue siendo demasiado complejo, usar el Bounding Box como fallback
  cli::cli_alert_warning("Pol\u00edgono demasiado complejo ({nchar(wkt)} caracteres). Usando Bounding Box como fallback para la consulta API.")
  bbox <- sf::st_bbox(sf_obj)
  sf_bbox <- sf::st_as_sf(sf::st_as_sfc(bbox))
  
  # Copiar metadatos si existen
  if (!is.null(sf_obj$distrito)) sf_bbox$distrito <- sf_obj$distrito[1]
  if (!is.null(sf_obj$departamento)) sf_bbox$departamento <- sf_obj$departamento[1]
  if (!is.null(sf_obj$provincia)) sf_bbox$provincia <- sf_obj$provincia[1]
  
  return(sf_bbox)
}

#' Simplifica un poligono de tipo sf usando proyecciones UTM
#'
#' @param sf_obj Objeto sf con la geometria.
#' @param tolerancia_metros Tolerancia de simplificacion en metros (def: 100 metros).
#' @return Objeto sf simplificado en EPSG:4326.
simplificar_poligono <- function(sf_obj, tolerancia_metros = 100) {
  if (tolerancia_metros <= 0) {
    return(sf_obj)
  }
  
  centroide <- sf::st_coordinates(sf::st_centroid(sf::st_union(sf::st_transform(sf_obj, 4326))))[1, ]
  zona_utm <- max(1, min(60, floor((centroide[1] + 180) / 6) + 1))
  epsg_utm <- 32700 + zona_utm
  sf_utm <- sf::st_transform(sf_obj, crs = epsg_utm)
  
  sf_utm_sim <- sf::st_simplify(sf_utm, preserveTopology = TRUE, dTolerance = tolerancia_metros)
  sf_wgs84 <- sf::st_transform(sf_utm_sim, crs = 4326)
  sf_wgs84 <- sf::st_make_valid(sf_wgs84)
  
  return(sf_wgs84)
}

#' Convierte un objeto sf a formato WKT (Well-Known Text) para consultas GBIF
#'
#' @param sf_obj Objeto sf.
#' @return Una cadena de texto en formato WKT.
poligono_a_wkt <- function(sf_obj) {
  geom <- sf::st_geometry(sf_obj)
  geom <- sf::st_make_valid(geom)
  wkt <- sf::st_as_text(geom[[1]])
  
  if (nchar(wkt) > 1500) {
    cli::cli_warn("La geometr\u00eda WKT es extensa ({nchar(wkt)} caracteres). Puede provocar fallos en la consulta API de GBIF. Considere aumentar el par\u00e1metro de simplificaci\u00f3n.")
  }
  
  return(wkt)
}

#' Valida y normaliza un polígono aportado por el usuario
#'
#' Acepta una geometría u archivo espacial, lo transforma a WGS84, corrige
#' topología cuando es posible y unifica múltiples elementos en un único límite.
#' Es la preparación previa que usa [buscar_especies_poligono()].
#'
#' @param poligono Un objeto `sf`, `sfc` o `Spatial`, o una ruta de longitud uno
#'   a `.shp`, `.geojson`, `.gpkg` o `.kml`. Debe contener geometrías
#'   poligonales. Si no tiene CRS se asume EPSG:4326 y se emite una advertencia.
#' @param nombre `NULL` o una etiqueta de texto no vacía para resultados y
#'   exportaciones. Si `poligono` es una ruta y `nombre` es `NULL`, se usa el
#'   nombre del archivo sin extensión; para objetos espaciales se usa
#'   `"Poligono_Personalizado"`.
#' @return Un objeto `sf` válido de una fila en EPSG:4326, con las columnas
#'   `unidad`, `distrito`, `provincia` y `departamento`. Las tres últimas se
#'   rellenan con `NA` porque el límite no procede de una unidad administrativa.
#' @examples
#' coords <- matrix(c(-77.05, -12.10, -77.01, -12.10, -77.01, -12.05,
#'                    -77.05, -12.05, -77.05, -12.10), ncol = 2, byrow = TRUE)
#' zona <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
#' preparar_poligono_usuario(zona, nombre = "Zona de prueba")
#' @export
preparar_poligono_usuario <- function(poligono, nombre = NULL) {
  loadNamespace("sf")
  
  if (missing(poligono) || is.null(poligono)) {
    cli::cli_abort("Debe proporcionar un pol\u00edgono (objeto {.cls sf} o ruta a archivo espacial).")
  }
  
  # 1. Leer desde archivo si es character
  if (is.character(poligono)) {
    if (length(poligono) != 1L || !nzchar(trimws(poligono))) {
      cli::cli_abort("La ruta del archivo espacial no es v\u00e1lida.")
    }
    if (!file.exists(poligono)) {
      cli::cli_abort("No se encontr\u00f3 el archivo espacial en la ruta: {.file {poligono}}")
    }
    if (is.null(nombre) || !nzchar(trimws(nombre))) {
      nombre <- tools::file_path_sans_ext(basename(poligono))
    }
    sf_obj <- tryCatch({
      sf::st_read(poligono, quiet = TRUE)
    }, error = function(e) {
      cli::cli_abort("Error al leer archivo espacial {.file {poligono}}: {e$message}")
    })
  } else if (inherits(poligono, c("sf", "sfc", "Spatial"))) {
    sf_obj <- sf::st_as_sf(poligono)
    if (is.null(nombre) || !nzchar(trimws(nombre))) {
      nombre <- "Poligono_Personalizado"
    }
  } else {
    cli::cli_abort("{.arg poligono} debe ser un objeto {.cls sf}/{.cls sfc} o una ruta a un archivo espacial (.shp, .geojson, .gpkg, .kml).")
  }
  
  if (nrow(sf_obj) == 0) {
    cli::cli_abort("El objeto espacial no contiene registros ni geometr\u00edas.")
  }
  
  # 2. Validar y estandarizar CRS a EPSG:4326
  crs_actual <- sf::st_crs(sf_obj)
  if (is.na(crs_actual)) {
    cli::cli_warn("El pol\u00edgono carece de sistema de referencia (CRS). Se asumir\u00e1 EPSG:4326 (WGS84).")
    sf::st_crs(sf_obj) <- 4326
  } else if (crs_actual != sf::st_crs(4326)) {
    cli::cli_alert_info("Reproyectando geometr\u00eda desde {.val {crs_actual$input}} a {.val EPSG:4326} (WGS84)...")
    sf_obj <- sf::st_transform(sf_obj, crs = 4326)
  }
  
  # 3. Validar y corregir topologia
  sf_obj <- sf::st_make_valid(sf_obj)
  
  # 4. Unificar si tiene multiples filas/poligonos
  if (nrow(sf_obj) > 1) {
    cli::cli_alert_info("El archivo contiene {nrow(sf_obj)} elementos. Unificando en una sola entidad...")
    geom_union <- sf::st_union(sf_obj)
    sf_obj <- sf::st_as_sf(sf::st_sfc(geom_union, crs = 4326))
  }
  
  # 5. Asegurar tipo poligonal
  geom_type <- as.character(sf::st_geometry_type(sf_obj, by_geometry = FALSE))
  if (!geom_type %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")) {
    cli::cli_abort("La geometr\u00eda debe ser poligonal ({.cls POLYGON} o {.cls MULTIPOLYGON}), se detect\u00f3: {.cls {geom_type}}")
  }
  
  # 6. Asignar metadatos descriptivos
  sf_obj$unidad <- nombre
  sf_obj$distrito <- NA_character_
  sf_obj$provincia <- NA_character_
  sf_obj$departamento <- NA_character_
  
  return(sf_obj)
}
