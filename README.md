# Panel de articulos, medidas y precios

Prototipo funcional para validar con Ezequiel una vista de articulos unificada, pensada para trabajo remoto sin VPN.

La idea es que Ezequiel no consulte Tango, SQL ni recursos internos directamente. CHEMES prepara y combina internamente la informacion de articulos, stock, listas de precios, medidas, peso y fotos; el panel solo publica una vista controlada.

## Archivos

- `index.html`: prototipo estatico del panel.
- `scripts/export_articulos_panel.ps1`: exporta datos reales desde Tango SQL y saldos desde el servidor web.
- `data/articulos-data.js`: datos generados para el panel. Se crea al ejecutar el script.
- `docs/propuesta-panel-articulos.md`: propuesta funcional y tecnica.
- `docs/publicacion-y-actualizacion.md`: propuesta para publicar el panel y actualizar datos automaticamente.

## Como probar

Abrir `index.html` en un navegador. No requiere servidor ni instalacion de dependencias.

Para refrescar datos reales desde CASA_CENTRAL:

```powershell
$env:CHEMES_SQL_AXOFT_PASSWORD = "<password>"
.\scripts\export_articulos_panel.ps1
```

Conexiones usadas por defecto:

- Articulos, precios y medidas: `10.10.10.99\SQL_AXOFT`, base `CASA_CENTRAL`.
- Stock CD/CA/Colchoneria: `10.10.10.109\SQLEXPRESS_AXOFT`, base `Suc_ChemesWeb`.
- Fotos Prestashop: `C:\Users\rbaig\Documents\Codex\2026-06-11\nueva-necesidad-hay-que-hacer-un\prestashop_imagenes`.
- Listas de precios: 1, 2, 3, 4, 5, 6, 20, 21, 500, 501 y 504.
- Usuario: `Axoft`.

## Alcance inicial

- Listado principal de articulos por SKU.
- Datos logisticos: medidas, peso, estado de completitud.
- Stock separado por deposito: CD, Candioti y Colchoneria.
- Precios por listas 504, 500 y 501.
- Panel lateral de detalle con fotos y datos secundarios.
- Filtros para busqueda, deposito y alertas logisticas.
- Descarga Excel del listado filtrado.
- Asociacion de fotos por SKU desde carpeta Prestashop, incluyendo multiples fotos por articulo.

## Siguiente paso

Publicar el panel y sus datos en un recurso accesible para Ezequiel sin VPN, evitando exponer Tango/SQL directamente.
