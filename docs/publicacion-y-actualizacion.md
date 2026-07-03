# Publicacion y actualizacion del panel

## Objetivo

Publicar el panel para Ezequiel sin VPN y mantener actualizados articulos, precios, stock, medidas y fotos sin darle acceso directo a Tango o SQL.

## Recomendacion

Publicar una carpeta estatica con estos archivos:

- `index.html`
- `data/articulos-data.js`
- imagenes publicadas o una carpeta `images/` generada desde las fotos Prestashop

El usuario remoto entra al panel por HTTPS. El servidor interno ejecuta la actualizacion y reemplaza el archivo `data/articulos-data.js`.

## Opciones de publicacion

### Opcion A: IIS en servidor web existente

Usar `10.10.10.109` como servidor de publicacion, porque ya contiene datos web y stock.

Pasos generales:

1. Crear una carpeta, por ejemplo `C:\inetpub\wwwroot\panel-articulos`.
2. Copiar `index.html`, `data/`, `scripts/` y, si se publican fotos, `images/`.
3. Crear sitio o aplicacion en IIS.
4. Proteger acceso con usuario/clave, IP allowlist, Cloudflare Access, VPN liviana o autenticacion equivalente.
5. Publicar por HTTPS.

### Opcion B: hosting estatico externo

Publicar solo archivos estaticos en un hosting externo o bucket. En este caso, la actualizacion interna debe subir `articulos-data.js` y las fotos por un proceso controlado.

Es simple para Ezequiel, pero hay que cuidar permisos porque se publican precios y stock.

### Opcion C: Google Drive/Sheet como puente

Exportar Excel/CSV a Drive y que el panel consuma un archivo publicado. Es mas rapido de implementar, pero menos robusto para fotos, permisos finos y volumen de datos.

## Actualizacion automatica

Crear una tarea programada en Windows en el servidor que tenga acceso a:

- `10.10.10.99\SQL_AXOFT`
- `10.10.10.109\SQLEXPRESS_AXOFT`
- carpeta de fotos Prestashop
- carpeta publicada del panel

Comando sugerido:

```powershell
$env:CHEMES_SQL_AXOFT_PASSWORD = "<password>"
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ruta\panel-articulos\scripts\export_articulos_panel.ps1" -OutputPath "C:\ruta\panel-articulos\data\articulos-data.js"
```

Frecuencia sugerida:

- Articulos, medidas y precios: cada 2 o 4 horas.
- Stock: cada 30 o 60 minutos si Ezequiel lo necesita operativo.
- Fotos: diaria o bajo demanda, salvo que cambien muy seguido.

## Fotos

Actualmente el panel referencia fotos desde una carpeta local. Para acceso remoto, conviene publicar una copia de las imagenes junto al panel, por ejemplo:

- `images/A02000070.jpg`
- `images/A02000070_2.jpg`

Luego el exportador deberia generar rutas relativas (`images/A02000070.jpg`) en lugar de `file:///...`.

## Tareas pendientes recomendadas

- Confirmar si el sitio se publicara en IIS interno o hosting externo.
- Definir seguridad de acceso para Ezequiel.
- Definir si las fotos se copian al sitio o se sirven desde otro origen.
- Validar periodicamente que el stock de colchoneria siga saliendo de depositos `50` y `70`.
- Crear tarea programada y log de ejecucion.
