# Propuesta: panel de visibilidad de articulos para WEB/logistica

## Contexto

Ezequiel necesita consultar datos de productos para agilizar altas y mantenimiento en Producteca, Avenida, Macro, BNA y otros canales. Trabaja remoto y sin VPN, por lo que no conviene darle acceso directo a Tango, SQL ni recursos internos de CHEMES.

La API estandar de Tango permite obtener datos base de productos, pero no expone de forma directa los campos adicionales personalizados donde CHEMES carga medidas, peso y otros datos logisticos. Ademas, precios por listas, stock por deposito, fotos y datos secundarios no necesariamente salen de una unica consulta.

## Enfoque recomendado

Crear una capa interna de preparacion de datos y publicar hacia Ezequiel un panel de visibilidad.

El panel no deberia conectarse directamente a Tango. Deberia consumir datos ya combinados desde CHEMES.

## Fuentes a combinar

- Articulos: SKU, descripcion, codigo de barras, rubro, marca y datos base.
- Campos adicionales logisticos: alto, ancho, largo/profundidad, peso y observaciones.
- Stock por deposito: CD, Candioti y Colchoneria.
- Listas de precios: 504, 500 y 501.
- Fotos y datos secundarios: imagenes, descripcion extendida, atributos, estado para marketplaces.

## Vista principal

La primera pantalla deberia ser una grilla operativa con todos los articulos y columnas pensadas para escaneo rapido:

- SKU.
- Descripcion/titulo.
- Codigo de barras.
- Marca/rubro.
- Medidas.
- Peso.
- Stock CD.
- Stock Candioti.
- Stock Colchoneria.
- Precio lista 504.
- Precio lista 500.
- Precio lista 501.
- Estado logistico.

## Vista secundaria

Al seleccionar un articulo, el panel debe mostrar un detalle con informacion ampliada:

- Fotos del producto.
- Descripcion extendida.
- Campos secundarios.
- Validaciones logisticas.
- Alertas por medidas faltantes, peso faltante, stock disponible sin ficha completa, o diferencia de precios.
- Posible salida/exportacion para Producteca u otros canales.

## Seguridad y acceso

Como Ezequiel trabaja sin VPN, el acceso deberia ser externo pero controlado:

- Sin conexion directa a Tango o SQL desde su equipo.
- Publicacion de datos procesados desde CHEMES.
- Acceso por usuario o link controlado.
- Idealmente solo lectura.
- Auditoria simple de fecha/hora de actualizacion.

## Arquitectura sugerida

1. Consultas internas a Tango/SQL/Connect.
2. Proceso interno de combinacion por SKU.
3. Generacion de dataset normalizado.
4. Publicacion en panel web, endpoint intermedio o archivo controlado.
5. Vista operativa para Ezequiel.

## Integracion inicial realizada

Se conecto contra `10.10.10.99\SQL_AXOFT`, base `CASA_CENTRAL`, para articulos, precios y medidas.

Para saldos se conecto contra `10.10.10.109\SQLEXPRESS_AXOFT`, base `Suc_ChemesWeb`.

Para fotos se usa la carpeta local de imagenes de Prestashop:

`C:\Users\rbaig\Documents\Codex\2026-06-11\nueva-necesidad-hay-que-hacer-un\prestashop_imagenes`

Fuentes detectadas:

- Articulos: `STA11`.
- Listas de precios 504, 500 y 501: `GVA17` / `GVA10`.
- Listas de precios 1, 2, 3, 4, 5, 6, 20, 21, 500, 501 y 504: `GVA17` / `GVA10`.
- Stock por deposito: `10.10.10.109`, base `Suc_ChemesWeb`, tabla `STA19`.
- Medidas, volumen y peso: `STA11.CAMPOS_ADICIONALES`.
- Ruta de foto interna, cuando existe: `STA11.BMP`.
- Fotos Prestashop: archivos nombrados por SKU, por ejemplo `A02000070.jpg`, `A02000070_2.jpg`.

Mapeo logistico inicial:

- Alto: `CA_ALTO_1_CM`.
- Ancho: `CA_ANCHO_1_CM`.
- Largo/profundidad: `CA_LARGO_1_CM`.
- Volumen: `CA_VOLUMEN`.
- Peso: `CA_NUMBER_1733331476658`.
- Bultos/dato secundario a confirmar: `CA_NUMBER_1733331481626`.

Mapeo de stock inicial:

- CD: deposito `CD`, desde `10.10.10.109`.
- Candioti: deposito `CA`, desde `10.10.10.109`.
- Colchoneria: depositos `50` y `70`.

El script `scripts/export_articulos_panel.ps1` genera `data/articulos-data.js`, que el panel carga automaticamente.

Validacion actual de saldos exportados:

- SKUs con stock CD distinto de cero: 1101.
- Total unidades CD exportadas: 39879.
- SKUs con stock Candioti distinto de cero: 581.
- Total unidades Candioti exportadas: 1552.
- Stock Colchoneria exportado: depositos `50` y `70`.

El panel incluye descarga Excel del listado filtrado visible.

Validacion actual de listas exportadas:

- 1 CONTADO.
- 2 3 CUOTAS.
- 3 6 CUOTAS.
- 4 9 CUOTAS.
- 5 12 CUOTAS.
- 6 18 CUOTAS.
- 20 Precios WEB.
- 21 PRECIOS ANTES WEB.
- 500 CUENTA 1 BNA - 18CSI.
- 501 CUENTA 2 BNA - EFICI.
- 504 CUENTA MACRO PREMIA.

Validacion actual de fotos:

- Archivos fuente detectados en carpeta Prestashop: 20634.
- SKUs del panel con una o mas fotos asociadas: 3483.
- Fotos asociadas al dataset actual: 12668.
- La asociacion usa coincidencia por SKU exacto y, para variantes con sufijo, fallback al SKU base.

## Entregable inicial

Se deja un panel estatico en `index.html` que carga datos reales exportados desde Tango SQL y mantiene datos de muestra solo como respaldo si no existe el archivo generado.
