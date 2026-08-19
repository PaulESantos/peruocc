# visualize.R
# Funciones para graficar los resultados espaciales del proyecto.

#' Grafica el mapa de ocurrencias sobre el poligono de la unidad administrativa
#'
#' @param resultado_lista Lista de resultados devuelta por buscar_especies_peru(), buscar_especies_distrito() o buscar_especies_provincia().
#' @param color_por Columna para clasificar los colores ("source" por defecto, o "kingdom").
#' @param guardar_mapa Logico; si es TRUE guarda el grafico en results/ como PNG (def: TRUE).
#' @return El objeto de grafico ggplot.
#' @export
graficar_ocurrencias <- function(resultado_lista, color_por = "source", guardar_mapa = TRUE) {
  unidad_sf <- if (!is.null(resultado_lista$unidad_sf)) resultado_lista$unidad_sf else resultado_lista$distrito_sf
  ocurrencias <- resultado_lista$ocurrencias
  resumen <- resultado_lista$resumen
  
  nombre_unidad <- if (!is.null(resumen$unidad)) resumen$unidad else if (!is.null(resumen$distrito) && !is.na(resumen$distrito)) resumen$distrito else resumen$provincia
  nivel_unidad <- if (!is.null(resumen$nivel)) tools::toTitleCase(resumen$nivel) else "Distrito"
  nombre_dep <- if (!is.null(resumen$departamento) && !is.na(resumen$departamento)) resumen$departamento else "No especificado"
  
  # Paleta de colores esteticos
  colores_origen <- c("GBIF" = "#1f78b4", "iNaturalist" = "#33a02c")
  colores_reino <- c("Plantae" = "#2e7d32", "Animalia" = "#d32f2f", "Otros / Desconocido" = "#757575")
  
  # Crear grafico basico
  g <- ggplot2::ggplot() +
    # Capa del poligono de la unidad
    ggplot2::geom_sf(data = unidad_sf, fill = "#f9f6f0", color = "#3e2723", linewidth = 0.8)
  
  # Si hay ocurrencias, superponer los puntos
  if (!is.null(ocurrencias) && nrow(ocurrencias) > 0) {
    ocurrencias_clean <- dplyr::filter(ocurrencias, !is.na(decimalLongitude) & !is.na(decimalLatitude))
    
    if (nrow(ocurrencias_clean) > 0) {
      ocurrencias_sf <- sf::st_as_sf(
        ocurrencias_clean, 
        coords = c("decimalLongitude", "decimalLatitude"), 
        crs = 4326, 
        remove = FALSE
      )
      
      if (color_por == "kingdom") {
        ocurrencias_sf <- dplyr::mutate(ocurrencias_sf, kingdom = ifelse(is.na(kingdom), "Otros / Desconocido", kingdom))
      }
      
      g <- g + 
        ggplot2::geom_sf(data = ocurrencias_sf, ggplot2::aes(color = .data[[color_por]]), size = 2.2, alpha = 0.75)
      
      if (color_por == "source") {
        g <- g + 
          ggplot2::scale_color_manual(values = colores_origen, name = "Base de Datos")
      } else if (color_por == "kingdom") {
        g <- g + 
          ggplot2::scale_color_manual(values = colores_reino, name = "Reino")
      }
    } else {
      cat("[VISUALIZACION] Nota: Los registros encontrados carecen de coordenadas validas para ser graficados.\n")
    }
  } else {
    cat("[VISUALIZACION] Nota: No se encontraron registros de ocurrencias para graficar.\n")
  }
  
  # Formatear el diseno y leyendas
  g <- g +
    ggplot2::labs(
      title = sprintf("Ocurrencias de Biodiversidad: %s de %s", nivel_unidad, nombre_unidad),
      subtitle = sprintf("Departamento: %s | Total: %d registros (GBIF: %d, iNaturalist: %d)", 
                         nombre_dep, resumen$total_registros, resumen$registros_gbif, resumen$registros_inat),
      x = "Longitud",
      y = "Latitud",
      caption = sprintf("Fuente: GBIF & iNaturalist | Generado: %s | Proyeccion: WGS84", Sys.Date())
    ) +
    ggplot2::theme_minimal(base_family = "sans") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 14, color = "#212121", hjust = 0.5),
      plot.subtitle = ggplot2::element_text(size = 10, color = "#616161", hjust = 0.5),
      plot.caption = ggplot2::element_text(size = 8, color = "#9e9e9e", face = "italic"),
      panel.grid.major = ggplot2::element_line(color = "#e0e0e0", linetype = "dashed"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.background = ggplot2::element_rect(fill = "#fdfdfd", color = NA),
      legend.position = "bottom",
      legend.box.background = ggplot2::element_rect(color = "#e0e0e0", fill = "white", linewidth = 0.5),
      legend.key = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 8, color = "#757575"),
      axis.title = ggplot2::element_text(size = 9, color = "#424242")
    )
  
  # Guardar el grafico si esta solicitado y hay datos
  if (guardar_mapa) {
    dir.create(ruta_peruocc("results"), recursive = TRUE, showWarnings = FALSE)
    
    unidad_clean <- gsub(" ", "_", tolower(normalizar_texto(nombre_unidad)))
    nombre_img <- ruta_peruocc("results", sprintf("mapa_%s_%s_%s.png", unidad_clean, color_por, format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")))
    
    tryCatch({
      ggplot2::ggsave(nombre_img, plot = g, width = 8, height = 7, dpi = 300, bg = "white")
      cat(sprintf("[VISUALIZACION] Mapa estatico guardado en: '%s'\n", nombre_img))
    }, error = function(e) {
      cat("[VISUALIZACION] Error al guardar el mapa en archivo: ", e$message, "\n")
    })
  }
  
  return(g)
}
