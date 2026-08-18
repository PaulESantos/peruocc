# visualize.R
# Funciones para graficar los resultados espaciales del proyecto.

#' Grafica el mapa de ocurrencias sobre el poligono del distrito
#'
#' @param resultado_lista Lista de resultados devuelta por buscar_especies_distrito().
#' @param color_por Columna para clasificar los colores ("source" por defecto, o "kingdom").
#' @param guardar_mapa Logico; si es TRUE guarda el grafico en data/ como PNG (def: TRUE).
#' @return El objeto de grafico ggplot.
#' @export
graficar_ocurrencias <- function(resultado_lista, color_por = "source", guardar_mapa = TRUE) {
  distrito_sf <- resultado_lista$distrito_sf
  ocurrencias <- resultado_lista$ocurrencias
  resumen <- resultado_lista$resumen
  
  nombre_distrito <- resumen$distrito
  nombre_dep <- resumen$departamento
  
  # Paleta de colores esteticos
  colores_origen <- c("GBIF" = "#1f78b4", "iNaturalist" = "#33a02c")
  colores_reino <- c("Plantae" = "#2e7d32", "Animalia" = "#d32f2f", "Otros / Desconocido" = "#757575")
  
  # Crear grafico basico
  g <- ggplot2::ggplot() +
    # Capa del poligono del distrito
    ggplot2::geom_sf(data = distrito_sf, fill = "#f9f6f0", color = "#3e2723", linewidth = 0.8)
  
  # Si hay ocurrencias, superponer los puntos
  if (!is.null(ocurrencias) && nrow(ocurrencias) > 0) {
    # Eliminar registros con coordenadas NA
    ocurrencias_clean <- dplyr::filter(ocurrencias, !is.na(decimalLongitude) & !is.na(decimalLatitude))
    
    if (nrow(ocurrencias_clean) > 0) {
      # Convertir a objeto espacial sf
      ocurrencias_sf <- sf::st_as_sf(
        ocurrencias_clean, 
        coords = c("decimalLongitude", "decimalLatitude"), 
        crs = 4326, 
        remove = FALSE
      )
      
      # Si clasificamos por reino, rellenar NAs
      if (color_por == "kingdom") {
        ocurrencias_sf <- dplyr::mutate(ocurrencias_sf, kingdom = ifelse(is.na(kingdom), "Otros / Desconocido", kingdom))
      }
      
      # Anadir puntos de ocurrencias al grafico
      g <- g + 
        ggplot2::geom_sf(data = ocurrencias_sf, ggplot2::aes(color = .data[[color_por]]), size = 2.2, alpha = 0.75)
      
      # Asignar escalas de colores apropiadas
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
      title = sprintf("Ocurrencias de Biodiversidad: Distrito de %s", nombre_distrito),
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
    dir.create(ruta_peruspecies("results"), recursive = TRUE, showWarnings = FALSE)
    
    dist_clean <- gsub(" ", "_", tolower(normalizar_texto(nombre_distrito)))
    nombre_img <- ruta_peruspecies("results", sprintf("mapa_%s_%s_%s.png", dist_clean, color_por, format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")))
    
    tryCatch({
      ggplot2::ggsave(nombre_img, plot = g, width = 8, height = 7, dpi = 300, bg = "white")
      cat(sprintf("[VISUALIZACION] Mapa estatico guardado en: '%s'\n", nombre_img))
    }, error = function(e) {
      cat("[VISUALIZACION] Error al guardar el mapa en archivo: ", e$message, "\n")
    })
  }
  
  return(g)
}
