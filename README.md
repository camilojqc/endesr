# endesr

**`endesr`** es un paquete de R que facilita la descarga y carga de microdatos de la **Encuesta Demográfica y de Salud Familiar (ENDES)**, producida por el **Instituto Nacional de Estadística e Informática (INEI) del Perú**. Permite seleccionar años y módulos sin descargar manualmente los archivos desde el portal de microdatos.

Los datos se descargan en formato SPSS (`.sav`) a un directorio temporal y se cargan como objetos en la sesión de R. Al finalizar la ejecución, el paquete elimina los archivos temporales utilizados; **no se guardan copias permanentes de las bases en el proyecto**.

## Instalación

`endesr` se distribuye mediante GitHub. Para instalar la versión de desarrollo:

```r
install.packages("remotes") # Solo si no está instalado
remotes::install_github("camilojqc/endesr")
```

Una vez instalado:

```r
library(endesr)
```

## Uso básico

### Cargar un módulo de un año

```r
cargar_endes(2025, modulo = "hogar")
```

Cada archivo SPSS del módulo se carga como un objeto independiente con el patrón `ENDES_<ARCHIVO>_<AÑO>`; por ejemplo, `ENDES_RECH0_2025`. Los objetos quedan disponibles en el entorno desde el que se llama a la función.

```r
# Identificar los objetos cargados
ls(pattern = "^ENDES_")

# Explorar una base, si está incluida en el módulo descargado
head(ENDES_RECH0_2025)
```

### Cargar varios años o módulos

```r
# Un módulo para varios años
cargar_endes(2021:2023, modulo = "encuestasalud")

# Varios módulos para un año
cargar_endes(2024, modulo = c("hogar", "violencia"))
```

Los módulos pueden indicarse mediante una **clave de texto** (por ejemplo, `"hogar"`) o mediante su **código numérico**. El paquete reconoce tanto la numeración usada hasta 2019 como la empleada desde 2020, y selecciona automáticamente el código correspondiente al año solicitado.

## Consultar años y módulos disponibles

```r
# Años reconocidos por el paquete
endes_anios()

# Módulos, identificadores y códigos del INEI
endes_modulos()
```

El paquete contempla **1996, 2000 y los años de 2004 a 2025**. La disponibilidad de cada módulo puede variar según el año; consulta la columna `desde` de `endes_modulos()` para identificar el primer año contemplado para cada módulo.

## Funciones principales

| Función | Descripción |
| --- | --- |
| `cargar_endes()` | Descarga módulos y carga sus bases como objetos en el entorno de R. |
| `endes_anios()` | Muestra los años admitidos por el paquete. |
| `endes_modulos()` | Muestra las claves, nombres y códigos de los módulos, incluidos los cambios de numeración. |

Para conocer los argumentos de una función, consulta su documentación en R:

```r
?cargar_endes
```

## Consideraciones de uso

- **Conexión y disponibilidad:** las descargas requieren acceso a internet y dependen de la disponibilidad del portal del INEI. Si un archivo no puede descargarse, el paquete puede emitir una advertencia.
- **Almacenamiento temporal:** los ZIP y archivos SPSS se gestionan temporalmente y se eliminan al finalizar la función en condiciones normales. Las bases cargadas permanecen en la memoria de la sesión de R, salvo que el usuario decida guardarlas.
- **Tamaño de los datos:** descargar varios módulos o años puede requerir tiempo y una cantidad considerable de memoria RAM.
- **Comparabilidad:** la correspondencia entre códigos de módulos no implica que las variables y sus definiciones sean idénticas entre años. Antes de combinar bases, se sugiere revisar la documentación metodológica del INEI.

## Fuente de datos y alcance

Los microdatos provienen del [portal de microdatos del INEI](https://proyectos.inei.gob.pe/microdatos/). **`endesr` es un desarrollo independiente, no oficial y sin afiliación con el INEI**; busca facilitar el acceso a los archivos.

## Licencia y contribuciones

El código de `endesr` se distribuye bajo la **licencia MIT**. Para comunicar errores o sugerir mejoras, utiliza la sección de [Issues del repositorio](https://github.com/camilojqc/endesr/issues).
