# AutoArrangeDisplays

Sistema bash para guardar y restaurar automáticamente configuraciones de monitores basado en la IP del entorno usando [displayplacer](https://github.com/jakehilborn/displayplacer).

## 📋 Requisitos

- **macOS** (OS X 10.5+)
- **displayplacer** - Herramienta para controlar displays
- **jq** (opcional) - Para mejor manejo de JSON (sino usa Python 3)

## 🚀 Instalación

### 1. Descargar displayplacer

```bash
# Descargar la última versión
cd ~/MyDEVELOP/AutoArrangeDisplays
wget https://github.com/jakehilborn/displayplacer/releases/download/v1.4.0/displayplacer -O displayplacer
chmod +x displayplacer

# O descárgalo manualmente desde:
# https://github.com/jakehilborn/displayplacer/releases
```

### 2. Instalar dependencias opcionales (recomendado)

```bash
# macOS
brew install jq
```

## 📖 Uso

### Capturar una configuración de monitores

Primero, acomoda tus monitores como deseas y luego guarda la configuración:

```bash
# Guardar con nombre automático por IP
./analyser.sh save home

# Guardar con IP específica
./analyser.sh save office 192.168.1.100

# Listar todas las configuraciones guardadas
./analyser.sh list

# Eliminar una configuración
./analyser.sh delete home
```

### Restaurar una configuración

```bash
# Restaurar automáticamente según la IP actual
./runner.sh

# Aplicar explícitamente por IP actual
./runner.sh --apply

# Restaurar por IP específica
./runner.sh --ip 192.168.1.100

# Restaurar por nombre de configuración
./runner.sh --name home

# Listar configuraciones disponibles
./runner.sh --list
```

## 📁 Estructura de datos

Las configuraciones se guardan en `data.txt` en formato JSON:

```json
[
  {
    "name": "home",
    "ip": "192.168.1.50",
    "config": "id:FF26A8FE-EFE1-41FD-ABD2-BDD5BA92AED2 res:3440x1440 hz:59 color_depth:8 scaling:off origin:(0,0) degree:0 ...",
    "timestamp": 1673875432,
    "created": "2023-01-16T10:23:52"
  },
  {
    "name": "office",
    "ip": "192.168.1.100",
    "config": "id:FF26A8FE-EFE1-41FD-ABD2-BDD5BA92AED2 res:1920x1080 hz:60 ...",
    "timestamp": 1673875445,
    "created": "2023-01-16T10:24:05"
  }
]
```

## 🔄 Flujo de trabajo típico

### Setup Inicial (en cada ubicación)

```bash
# En casa: configurar monitores y guardar
./analyser.sh save home

# En la oficina: configurar monitores y guardar
./analyser.sh save office 192.168.1.100
```

### Uso automático (login script)

Agregar a tu `~/.zshrc` o `~/.bash_profile`:

```bash
# Restaurar configuración de monitores automáticamente
~/MyDEVELOP/AutoArrangeDisplays/runner.sh --apply 2>/dev/null || true
```

O crear un launch agent para ejecutar automáticamente al login:

```bash
# Crear archivo LaunchAgent
cat > ~/Library/LaunchAgents/com.autoarrangedisplays.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.autoarrangedisplays</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/mp0644/MyDEVELOP/AutoArrangeDisplays/runner.sh</string>
    <string>--apply</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>300</integer>
</dict>
</plist>
EOF

# Cargar el agent
launchctl load ~/Library/LaunchAgents/com.autoarrangedisplays.plist
```

## 🔍 Troubleshooting

### "displayplacer no encontrado"
Descarga displayplacer desde https://github.com/jakehilborn/displayplacer/releases y colócalo en la carpeta del proyecto.

### "No hay configuraciones guardadas"
Primero corre: `./analyser.sh save <nombre_config>`

### La configuración no se aplica
1. Verifica que los monitores están conectados
2. Revisa la IP actual con: `ifconfig | grep "inet "`
3. Intenta manualmente: `./runner.sh --list` para ver configuraciones disponibles

### Permisos denegados
```bash
chmod +x analyser.sh runner.sh displayplacer
```

## 📝 Archivos

- **analyser.sh** - Captura y guarda configuraciones de monitores
- **runner.sh** - Restaura configuraciones según IP
- **data.txt** - Base de datos JSON con las configuraciones guardadas
- **investigation.txt** - Notas de investigación (opcional)

## 🛠️ Ejemplos avanzados

### Ver la configuración sin aplicarla

```bash
# Listar todas
./analyser.sh list

# Por IP (consultar runner.sh)
./runner.sh --list
```

### Editar manualmente una configuración

Edita `data.txt` directamente (es JSON estándar).

### Backup de configuraciones

```bash
# Hacer backup
cp data.txt data.txt.backup

# Restaurar desde backup
cp data.txt.backup data.txt
```

## 📄 Licencia

Este proyecto usa [displayplacer](https://github.com/jakehilborn/displayplacer) que está bajo licencia MIT.

## ✨ Características

✅ Guardar configuración de monitores con nombre personalizado  
✅ Restauración automática según IP del entorno  
✅ Búsqueda por nombre de configuración  
✅ Formato JSON para fácil edición  
✅ Sin dependencias (excepto displayplacer)  
✅ Compatible con macOS  
✅ Timestamps para auditoría  

---

**Última actualización:** Enero 2026
