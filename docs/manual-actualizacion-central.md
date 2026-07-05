# Manual operativo: actualizacion automatica del Panel de Articulos

## Objetivo

Mantener actualizado el panel publico de articulos, medidas, stock y precios sin depender de una notebook.

La actualizacion debe ejecutarse desde el servidor CENTRAL `10.10.10.99`, en la carpeta:

```text
F:\Tarea\DashBoard_comercial\Articulos_Medidas
```

El panel publicado esta en GitHub Pages:

```text
https://bjcbaigo.github.io/ch-panelArtMedidas/
```

## Flujo de actualizacion

1. La tarea programada de Windows ejecuta `scripts\update_and_publish_panel.ps1`.
2. El script sincroniza el repositorio local con GitHub.
3. Ejecuta `scripts\export_articulos_panel.ps1`.
4. El exportador consulta SQL/Tango y genera archivos `data\articulos-data-*.js` y `data\articulos-manifest.js`.
5. Si hay cambios, el script hace commit y push a `origin/master`.
6. GitHub Pages publica los cambios en la URL del panel.

## Fuentes de datos

- Articulos, precios y medidas: `10.10.10.99\SQL_AXOFT`, base `CASA_CENTRAL`.
- Stock CD/CA/Colchoneria: `10.10.10.109\SQLEXPRESS_AXOFT`, base `Suc_ChemesWeb`.
- Repositorio GitHub: `https://github.com/bjcbaigo/ch-panelArtMedidas.git`.

## Archivos principales

```text
F:\Tarea\DashBoard_comercial\Articulos_Medidas\index.html
F:\Tarea\DashBoard_comercial\Articulos_Medidas\data\articulos-manifest.js
F:\Tarea\DashBoard_comercial\Articulos_Medidas\scripts\export_articulos_panel.ps1
F:\Tarea\DashBoard_comercial\Articulos_Medidas\scripts\update_and_publish_panel.ps1
F:\Tarea\DashBoard_comercial\Articulos_Medidas\install_central_task.ps1
```

## Tarea programada

Nombre esperado:

```text
CHEMES - Actualizar Panel Articulos
```

Consultar estado:

```powershell
Get-ScheduledTaskInfo -TaskName "CHEMES - Actualizar Panel Articulos"
```

Ejecutar manualmente:

```powershell
Start-ScheduledTask -TaskName "CHEMES - Actualizar Panel Articulos"
```

Ver configuracion:

```powershell
Get-ScheduledTask -TaskName "CHEMES - Actualizar Panel Articulos" | Format-List *
```

## Log de ejecucion

El log principal queda en:

```text
F:\Tarea\DashBoard_comercial\Articulos_Medidas\logs\update-panel.log
```

Ver las ultimas lineas:

```powershell
Get-Content "F:\Tarea\DashBoard_comercial\Articulos_Medidas\logs\update-panel.log" -Tail 80
```

Una ejecucion correcta debe terminar con:

```text
Actualizacion publicada correctamente
```

## Verificacion rapida

1. Abrir el panel:

```text
https://bjcbaigo.github.io/ch-panelArtMedidas/
```

2. Revisar arriba a la derecha la etiqueta:

```text
Datos reales: yyyy-mm-dd hh:mm:ss (... articulos)
```

3. Si no se ve la fecha nueva, probar `Ctrl+F5` o ventana incognito. GitHub Pages puede tardar algunos minutos.

## Instalacion o reinstalacion en CENTRAL

Abrir PowerShell como administrador en CENTRAL y ejecutar:

```powershell
cd F:\Tarea\DashBoard_comercial\Articulos_Medidas
.\install_central_task.ps1 -SqlPassword "Axoft"
```

Si se quiere registrar la tarea con usuario y password explicitos:

```powershell
whoami
.\install_central_task.ps1 -SqlPassword "Axoft" -TaskUser "server-vera\server" -TaskPassword "<password-windows>"
```

## Requisitos

- Git for Windows instalado en CENTRAL.
- Acceso desde CENTRAL a SQL `10.10.10.99\SQL_AXOFT`.
- Acceso desde CENTRAL a SQL `10.10.10.109\SQLEXPRESS_AXOFT`.
- Acceso desde CENTRAL a GitHub.
- Credenciales GitHub configuradas para poder hacer `git push`.
- Variable de entorno `CHEMES_SQL_AXOFT_PASSWORD` definida para el usuario que ejecuta la tarea.

El instalador intenta configurar la variable de entorno automaticamente al recibir `-SqlPassword`.

## Problemas frecuentes

### Git pide identidad

Sintoma:

```text
Author identity unknown
```

Solucion:

```powershell
git config user.name "CHEMES Panel Bot"
git config user.email "panel-articulos@chemes.local"
```

Los scripts actuales ya lo configuran automaticamente dentro del repositorio.

### Git rechaza el push

Sintoma:

```text
rejected non-fast-forward
```

Causa usual: el repositorio local estaba atrasado o habia otra maquina publicando.

Solucion:

```powershell
cd F:\Tarea\DashBoard_comercial\Articulos_Medidas
git fetch origin
git pull --ff-only origin master
```

Luego ejecutar otra vez:

```powershell
.\scripts\update_and_publish_panel.ps1
```

### Cambios locales impiden pull

Sintoma:

```text
Your local changes would be overwritten by merge
```

Los scripts actuales guardan temporalmente cambios locales de `data\` antes de sincronizar. Si hiciera falta hacerlo a mano:

```powershell
git stash push -m "manual-stash-panel" -- data index.html
git pull --ff-only origin master
```

### SQL no conecta

Revisar:

- Que CENTRAL tenga red hacia `10.10.10.99` y `10.10.10.109`.
- Que la password SQL sea correcta.
- Que exista `CHEMES_SQL_AXOFT_PASSWORD`.

Ver variable:

```powershell
[Environment]::GetEnvironmentVariable("CHEMES_SQL_AXOFT_PASSWORD", "User")
```

### La tarea queda con LastTaskResult 267009

`267009` puede indicar que la tarea sigue ejecutandose. Esperar y volver a consultar:

```powershell
Start-Sleep -Seconds 30
Get-ScheduledTaskInfo -TaskName "CHEMES - Actualizar Panel Articulos"
```

Si el log muestra `Actualizacion publicada correctamente`, la corrida fue correcta.

## Nota importante

La tarea de la notebook `NB-RAUL` fue deshabilitada para evitar doble publicacion. La fuente operativa debe ser CENTRAL.
