# Códigos de encuesta de la ENDES por año.
# Fuente: catálogo de inei-microdatos (github.com/fiorellarmartins/inei-microdatos,
# mayo 2026) + 2025. Agrega una línea cuando el INEI publique un año nuevo.
.tabla_codigos <- c(
  "1996" = "32",  "2000" = "35",  "2004" = "120", "2005" = "150",
  "2006" = "183", "2007" = "194", "2008" = "209", "2009" = "238",
  "2010" = "260", "2011" = "290", "2012" = "323", "2013" = "407",
  "2014" = "441", "2015" = "504", "2016" = "548", "2017" = "605",
  "2018" = "638", "2019" = "691", "2020" = "739", "2021" = "760",
  "2022" = "786", "2023" = "910", "2024" = "968", "2025" = "1038"
)

# Módulos de la ENDES. En 2020 el INEI cambió la numeración, pero el contenido es
# el mismo: 'antiguo' se usa hasta 2019 y 'nuevo' desde 2020. 'desde' es el
# primer año en que existe el módulo. 'clave' sirve para pedirlo por texto.
.tabla_modulos <- data.frame(
  clave   = c("hogar", "vivienda", "mef", "nacimientos", "embarazo",
              "inmunizacion", "nupcialidad", "sida", "violencia",
              "antropometria", "disciplina", "encuestasalud", "programas"),
  nombre  = c("Caracter\u00EDsticas del Hogar", "Caracter\u00EDsticas de la Vivienda",
              "Datos B\u00E1sicos de MEF", "Historia de Nacimiento",
              "Embarazo, Parto, Puerperio y Lactancia", "Inmunizaci\u00F3n y Salud",
              "Nupcialidad, Fecundidad, C\u00F3nyuge y Mujer",
              "Conocimiento de Sida y uso del cond\u00F3n",
              "Mortalidad Materna, Violencia Familiar", "Peso y talla, Anemia",
              "Disciplina Infantil", "Encuesta de salud", "Programas Sociales"),
  antiguo = c("64", "65", "66", "67", "69", "70", "71", "72", "73", "74",
              "413", "414", "569"),
  nuevo   = as.character(1629:1641),
  desde   = c(rep(1996, 10), 2013, 2013, 2014)
)

#' Módulos de la ENDES
#'
#' Devuelve una tabla con los módulos de la ENDES, incluyendo sus
#' identificadores, nombres y códigos numéricos correspondientes a los
#' periodos anterior (hasta 2019) y posterior (desde 2020) al cambio
#' de numeración implementado por el INEI.
#'
#' @return Un `data.frame` con las siguientes columnas:
#'   \describe{
#'     \item{clave}{Identificador textual del módulo.}
#'     \item{nombre}{Nombre descriptivo del módulo.}
#'     \item{antiguo}{Código numérico utilizado hasta 2019.}
#'     \item{nuevo}{Código numérico utilizado desde 2020.}
#'     \item{desde}{Primer año de disponibilidad del módulo.}
#'   }
#' @export
#' @examples
#' endes_modulos()
endes_modulos <- function() .tabla_modulos

#' Años disponibles de la ENDES
#'
#' Devuelve los años de la ENDES disponibles para su carga mediante
#' [cargar_endes()]. Los registros web contemplan información de 1996, 2000 y
#' del periodo comprendido entre 2004 y el último año disponible.
#'
#' @return Vector de enteros con los años disponibles en el paquete,
#'   ordenados cronológicamente.
#' @export
#' @examples
#' endes_anios()
endes_anios <- function() as.integer(names(.tabla_codigos))

# Minúsculas y sin tildes, para comparar texto
.normalizar <- function(x) {
  chartr(
    "\u00E1\u00E9\u00ED\u00F3\u00FA\u00FC\u00F1",
    "aeiouun",
    tolower(trimws(x))
  )
}

# Convierte lo que pide el usuario en una fila de .tabla_modulos.
# Acepta el número (antiguo o nuevo) o la clave exacta. Si no coincide con
# ninguno, se detiene y muestra todas las opciones.
.resolver_modulo <- function(x) {
  m    <- .tabla_modulos
  fila <- which(m$antiguo == x | m$nuevo == x | m$clave == .normalizar(x))
  if (length(fila) == 1) return(fila)

  stop("No se pudo identificar \"", x, "\" como m\u00F3dulo de la ENDES. ",
       "Usa su n\u00FAmero o una de estas claves:\n",
       paste0("  \"", m$clave, "\" = ", m$nombre, collapse = "\n"), call. = FALSE)
}

# Código de encuesta del INEI para cada año (ej. 2023 -> "910").
# Si algún año no existe, se detiene y muestra los disponibles.
.codigo_para_anio <- function(anios) {
  cod <- .tabla_codigos[as.character(anios)]
  if (anyNA(cod)) {
    stop("No hay datos de la ENDES para: ", toString(anios[is.na(cod)]),
         ". A\u00F1os disponibles: ", toString(endes_anios()), ".", call. = FALSE)
  }
  unname(cod)
}

# Número de módulo que corresponde a un año, o NA si ese año no existe el módulo
.modulo_para_anio <- function(fila, anio) {
  m <- .tabla_modulos[fila, ]
  if (anio < m$desde || (anio == 2004 && m$antiguo == "74")) return(NA)  # 2004 sin Peso y talla
  if (anio >= 2020) m$nuevo else m$antiguo
}

# Descarga un zip con reintentos. TRUE si quedó un zip válido
# (si el módulo no existe, el INEI devuelve una página HTML en vez del zip).
.descargar_zip <- function(url, destino, reintentos) {
  for (i in seq_len(reintentos)) {
    ok <- tryCatch({
      utils::download.file(url, destino, mode = "wb", quiet = TRUE)
      nrow(utils::unzip(destino, list = TRUE)) > 0
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok) return(TRUE)
    Sys.sleep(2)
  }
  FALSE
}

# Extrae solo los .sav del zip y devuelve sus rutas. Al no extraer la
# documentación, se evitan los PDF con tildes en el nombre que hacen fallar a
# unzip en Mac/Linux ("Illegal byte sequence"), y se ahorra tiempo y disco.
.extraer_sav <- function(zip, carpeta) {
  sav <- grep("\\.sav$", utils::unzip(zip, list = TRUE)$Name,
              ignore.case = TRUE, value = TRUE)
  utils::unzip(zip, files = sav, exdir = carpeta, junkpaths = TRUE)
}

#' Cargar módulos de la ENDES en el entorno
#'
#' Descarga los módulos indicados desde el portal de microdatos del INEI en 
#' formato SPSS, utilizando un directorio temporal. Cada base se carga
#' directamente en el entorno de R como un objeto `ENDES_<ARCHIVO>_<AÑO>`
#' (por ejemplo, `ENDES_RECH0_2023`). Los archivos descargados se eliminan
#' automáticamente al finalizar el proceso, sin generar copias permanentes
#' en el almacenamiento local.
#'
#' @param anio Vector numérico con los años de la ENDES que se desean cargar.
#'   Por ejemplo, `2025` o `2021:2023`.
#' @param modulo Vector con los módulos que se desean cargar, identificados
#'   mediante sus códigos numéricos o claves textuales. Los códigos numéricos
#'   pueden corresponder a la numeración anterior (hasta 2019) o actual
#'   (desde 2020) del INEI y se ajustan automáticamente según el año
#'   solicitado. Las claves textuales permiten identificar los módulos
#'   mediante nombres abreviados (por ejemplo, `"hogar"` o `"encuestasalud"`).
#'   Consulte [endes_modulos()] para conocer los módulos disponibles.
#' @param entorno Entorno de R en el que se crean los objetos. Por defecto,
#'   se utiliza el entorno desde el que se llama a la función.
#' @param reintentos Número máximo de intentos de descarga por módulo.
#'   Por defecto, `3`.
#' @param silencio Valor lógico. Si es `TRUE`, suprime los mensajes de
#'   progreso durante la descarga y carga de los datos. Por defecto, `FALSE`.
#' @return Devuelve de manera invisible un vector de caracteres con los
#'   nombres de los objetos creados en el entorno de R.
#' @export
#' @examples
#' \dontrun{
#' # Cargar un módulo de un año
#' cargar_endes(2025, modulo = "hogar")
#'
#' # Cargar un módulo de varios años
#' cargar_endes(2021:2023, modulo = "encuestasalud")
#'
#' # Cargar varios módulos de un año
#' cargar_endes(2024, modulo = c("hogar", 1631, "violencia"))
#' }
cargar_endes <- function(anio, modulo, entorno = parent.frame(),
                         reintentos = 3, silencio = FALSE) {
  msg <- function(...) if (!silencio) message(...)

  # Validar todo antes de descargar nada
  codigos <- .codigo_para_anio(anio)
  filas   <- vapply(as.character(modulo), .resolver_modulo, integer(1))

  # Timeout alto y carpeta temporal; ambos se restauran/borran al salir
  old <- options(timeout = max(3600, getOption("timeout")))
  tmp <- tempfile("endes_")
  on.exit({ options(old); unlink(tmp, recursive = TRUE) }, add = TRUE)
  dir.create(tmp)

  url_base <- "https://proyectos.inei.gob.pe/iinei/srienaho/descarga/SPSS/"
  creados  <- character(0)

  for (k in seq_along(anio)) {
    for (fila in filas) {
      mod <- .modulo_para_anio(fila, anio[k])
      if (is.na(mod)) {
        warning(.tabla_modulos$nombre[fila], " no existe en la ENDES ", anio[k],
                "; se omite.", call. = FALSE)
        next
      }
      etiqueta <- paste0("M\u00F3dulo ", mod, " (", .tabla_modulos$nombre[fila],
                         ") de la ENDES ", anio[k])

      msg("Descargando ", etiqueta, "...")
      zip <- file.path(tmp, paste0(codigos[k], "-Modulo", mod, ".zip"))
      if (!.descargar_zip(paste0(url_base, basename(zip)), zip, reintentos)) {
        warning("No se pudo descargar el ", etiqueta, ".", call. = FALSE)
        next
      }

      archivos <- .extraer_sav(zip, file.path(tmp, sub("\\.zip$", "", basename(zip))))
      msg("  ", etiqueta, " descargado. Contiene ", length(archivos),
          if (length(archivos) == 1) " archivo." else " archivos.")

      for (f in archivos) {
        # ENDES_<ARCHIVO>_<AÑO>: mayúsculas, sin caracteres raros y con el año
        # aunque el archivo no lo traiga (RECH0.sav de 2023 -> ENDES_RECH0_2023)
        nom <- toupper(gsub("[^A-Za-z0-9_]", "_", tools::file_path_sans_ext(basename(f))))
        if (!grepl("(^|_)(19|20)[0-9]{2}(_|$)", nom)) nom <- paste0(nom, "_", anio[k])
        obj <- paste0("ENDES_", nom)

        # Algunos .sav antiguos solo se leen con encoding latin1
        datos <- tryCatch(haven::read_sav(f),
                          error = function(e) haven::read_sav(f, encoding = "latin1"))
        assign(obj, datos, envir = entorno)
        creados <- c(creados, obj)
        msg("  Cargado: ", obj, " (", nrow(datos), " filas, ", ncol(datos), " columnas)")
      }
      unlink(c(zip, archivos))   # liberar disco antes del siguiente módulo
    }
  }

  msg("Listo. Objetos en el entorno: ", toString(creados))
  invisible(creados)
}
