# Instalación de HLDM Anticheat / Chaos Server en Windows

[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | **Español**

Comportamiento runtime objetivo: [BEHAVIOR_CONTRACT_ES.md](BEHAVIOR_CONTRACT_ES.md).

Esta guía describe el **stack completo actual**, no solamente la configuración antigua `hldm_trap` + `hldm_detector`.

## 1. Elegir listen server de Steam o HLDS independiente

### Recomendado para el proyecto actual: Steam listen server

Usa una copia de Half-Life instalada desde Steam y crea el servidor desde `Multiplayer -> Create Server`.

Ventajas:

- el host ya está dentro de la partida;
- es fácil probar plugins en la misma máquina;
- Steam Friends / Join Game / Invite sigue el flujo normal de listen-server;
- el desarrollo actual de armas y herramientas administrativas se prueba principalmente en esta configuración.

Ruta típica:

```text
E:\SteamLibrary\steamapps\common\Half-Life
```

### HLDS independiente

Útil para un servidor permanente sin cliente de juego abierto. El repositorio conserva el instalador PowerShell para HLDS AppID 90, pero el conjunto experimental completo de plugins debe compararse siempre con el artifact actual de CI.

## 2. Cadena requerida

```text
Half-Life / HLDS
    -> Metamod
        -> AMX Mod X 1.10
            -> HLDM plugins
```

Módulos AMXX mínimos:

```text
Fakemeta
Ham Sandwich
nVault
```

Verificación después del arranque:

```text
meta list
amxx version
amxx modules
```

## 3. Obtener los `.amxx` compilados

GitHub Actions compila **todos** los archivos:

```text
src\*.sma
```

con AMX Mod X Compiler oficial `1.10.0.5479` y coloca los plugins resultantes en el artifact de CI.

El paquete de CI también contiene:

```text
addons\amxmodx\plugins\*.amxx
addons\amxmodx\configs\plugins\*.cfg
docs\*.md
```

Es preferible usar esos binarios frente a compilaciones improvisadas porque CI rechaza warnings de Pawn.

## 4. Instalar el stack completo en Half-Life de Steam

Cierra Half-Life completamente antes de reemplazar `.amxx`.

Copia los plugins a:

```text
<HalfLifeRoot>\valve\addons\amxmodx\plugins\
```

Copia los configs a:

```text
<HalfLifeRoot>\valve\addons\amxmodx\configs\plugins\
```

Ejemplo:

```text
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\plugins\
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\configs\plugins\
```

## 5. Limpieza crítica de plugins obsoletos

Antes de arrancar revisa:

```text
valve\addons\amxmodx\configs\plugins.ini
```

No deben cargarse a la vez varias versiones históricas de Weapon Comedy, por ejemplo:

```text
hldm_weapon_comedy.amxx
hldm_weapon_comedy_v2.amxx
hldm_weapon_comedy_v3.amxx
hldm_weapon_comedy_v4.amxx
```

Debe quedar activa **una sola versión actual**.

La misma regla se aplica a otros duplicados experimentales. Un `.amxx` viejo guardado en disco no es automáticamente peligroso; dos versiones listadas en `plugins.ini` procesando el mismo `Touch`, `Think` o `CmdStart` sí lo son.

## 6. Orden relativo recomendado

La lista completa depende de los módulos experimentales activados, pero las dependencias importantes son:

```text
hldm_trap.amxx
hldm_detector.amxx

# admin / punishment modules
hldm_admin_tools.amxx
hldm_runtime_guard.amxx
hldm_chaos.amxx
hldm_meat_demon.amxx
hldm_silent_misery.amxx
hldm_leader_curse.amxx

# weapon stack
hldm_weapon_comedy.amxx
hldm_weapon_lab.amxx
hldm_weapon_payloads.amxx
hldm_population_manager.amxx
hldm_hornet_policy.amxx
hldm_egon_factory.amxx
```

Reglas:

- cargar `hldm_trap` antes de `hldm_detector`;
- cargar Weapon Comedy antes de Weapon Lab;
- cargar `hldm_hornet_policy` después de otros módulos que puedan observar hornets;
- preferiblemente no cargar el viejo `hldm_hornet_fix`. Si permanece cargado, `hldm_hornetfix_enabled "0"` es obligatorio.

## 7. Ajustes actuales obligatorios de estabilidad

### Hornets

En `hldm_hornet_policy.cfg`:

```cfg
hldm_hornetpolicy_enabled "1"
hldm_hornetpolicy_max_active "10"
hldm_hornetpolicy_lifetime "3.20"
hldm_hornetfix_enabled "0"
```

En `hldm_weapon_lab.cfg`:

```cfg
hldm_weaponlab_manage_hornets "0"
hldm_weaponlab_rocket_hornets "0"
```

No permitas que varios plugins gestionen simultáneamente el lifetime/touch/removal del mismo hornet.

### Lanzagranadas del MP5

Para jugadores normales permanece stock. Ninguna versión antigua debe reemplazar secondary fire por cohetes dobles.

El config actual de Weapon Comedy no debe contener los antiguos parámetros experimentales del MP5 como:

```text
second_rocket
rocket_max_active
rocket_speed
```

### Python / revólver

Valores seguros actuales:

```cfg
hldm_weaponcomedy_python_self_damage "4.0"
hldm_weaponcomedy_python_self_damage_lethal "0"
hldm_weaponcomedy_python_suppress_stock_pvp_damage "1"
hldm_weaponcomedy_python_pellets "16"
hldm_weaponcomedy_python_pellet_damage "3.0"
hldm_weaponcomedy_python_spread "0.16"
hldm_weaponcomedy_python_range "4096.0"
hldm_weaponcomedy_python_recoil "220.0"
```

Regla crítica: el revólver no crea entidades nativas `crossbow_bolt`. Los 16 “virotes” extra son trazas hitscan visuales sin entidades persistentes.

### Egon

`hldm_egon_factory.amxx` corresponde únicamente al weapon id `10` de Egon.

Comprobación:

```text
amx_egonfactory_status
```

El lanzagranadas del MP5 nunca debe activar mensajes del aspirador.

### Population Manager

Valores seguros actuales:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Motivos:

- `addbot` no existe sin un bot-DLL compatible con ParaBot;
- crear tarde `monster_zombie` / `monster_headcrab` nativos puede provocar `PF_precache_sound_I` y `Host_Error`, porque la game DLL intenta precachear sonidos después de cargar el mapa.

No actives `hldm_population_monsters_enabled 1` en la implementación actual.

## 8. Iniciar un Steam listen server

Después de instalar Metamod/AMXX y los plugins:

1. Inicia Half-Life mediante Steam.
2. Abre `Multiplayer`.
3. Selecciona `Create Server`.
4. Elige mapa, número de jugadores y demás parámetros.
5. Inicia el servidor.

Si ya utilizas un launcher preparado, úsalo en lugar del inicio normal de Half-Life.

Abre la consola después de cargar el mapa.

## 9. Verificación inicial

```text
meta list
amxx version
amxx modules
amxx plugins
```

Los plugins HLDM actuales no deben mostrar:

```text
bad load
error
unknown
```

Comprobación del core:

```text
amx_ac_status
amx_trap_list
```

Comprobación de armas:

```text
amx_weaponcomedy_status
amx_hornetpolicy_status
amx_payload_status
amx_egonfactory_status
```

Comprobación de quiet modes:

```text
amx_quiet_status
```

## 10. Smoke test después de una actualización

No empieces inmediatamente una sesión de diez minutos de caos tras reemplazar `.amxx` de armas. Haz primero una prueba corta.

### MP5

```text
10 disparos alt-fire individuales
varios intentos manteniendo alt-fire
```

Esperado: una granada de contacto normal por evento stock, sin enjambre de cohetes y sin mensajes Egon/aspirador.

### RPG

```text
10 disparos individuales
```

Esperado: un cohete stock por disparo. Algunos pueden oscilar ligeramente. No se crean cohetes adicionales.

### Hornet Gun

Dispara varias ráfagas.

Esperado:

- máximo 10 hornets activos por propietario;
- el 11.º no hace explotar al más antiguo;
- tocar una pared no tiene por qué destruir al hornet;
- los hornets restantes terminan con una explosión controlada por lifetime.

### Python

Prueba:

```text
1 disparo contra una pared
6 disparos rápidos contra una pared
varios disparos contra un jugador
```

Esperado:

- trazadores/chispas;
- no aparecen 16 entidades físicas de ballesta;
- no aparecen 16 explosiones;
- no aparecen 48 snarks;
- el self-damage no mata al propietario con los valores por defecto.

### Ballesta real

Pruébala por separado para verificar que su propio impact/payload continúa funcionando. Python ya no comparte el mismo camino de entidad nativa.

### Egon

Dispara Egon varias veces. Los mensajes del aspirador pueden aparecer únicamente aquí.

## 11. Prueba de quiet punishment

Obtén el `userid` del servidor:

```text
status
```

Ejemplo:

```text
amx_quiet #17 betrayal
```

Prueba una granada de mano, granada de contacto del MP5 y RPG del cliente **marcado**. Después limpia el modo:

```text
amx_quiet #17 clear
```

`#17` es un server userid, no el índice del slot.

## 12. Administrador de AMX Mod X

Añade el SteamID a:

```text
valve\addons\amxmodx\configs\users.ini
```

Ejemplo:

```text
"STEAM_0:1:12345678" "" "abcdefghijklmnopqrstu" "ce"
```

Después ejecuta:

```text
amx_reloadadmins
```

o reinicia el servidor.

## 13. Scripts legacy del repositorio

El repositorio conserva:

```text
deploy\setup_hldm_server_windows.ps1
deploy\install_fresh_hlds_windows.ps1
deploy\uninstall_windows.ps1
```

Son útiles para instalar la cadena base Metamod + AMX Mod X + anticheat core. El proyecto ha crecido mucho más rápido que sus instaladores originales, por lo que **siempre debes comparar el conjunto completo de plugins activos con el artifact actual de CI y `src/*.sma`**.

Ejemplo de setup base:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RconPassword "PASSWORD_FUERTE" `
  -Hostname "HLDM" `
  -Port 27015 `
  -MaxPlayers 16
```

## 14. Compilación manual

Usa AMX Mod X Compiler `1.10.0.5479`.

Fuentes:

```text
src\*.sma
```

Compila cada `.sma` con `amxxpc.exe`. CI hace el mismo proceso automáticamente y rechaza warnings.

Comprobación local del contrato:

```text
python tools/check_contract.py
```

## 15. Diagnóstico de crashes

Cuando el servidor cae, copia la consola **desde el primer error**, no solo las dos últimas líneas.

Marcadores importantes:

```text
Host_Error:
PF_precache_sound_I:
PF_precache_model_I:
ED_Alloc:
SZ_GetSpace:
Invalid entity
Run time error
```

Ejemplo de una causa real ya encontrada:

```text
Host_Error: PF_precache_sound_I: 'zombie/claw_strike1.wav'
Precache can only be done in spawn functions
```

Los mensajes posteriores de `nVault`, disconnect, unload y `Server shutdown` fueron consecuencias del teardown, no la causa original.

## 16. Rollback

Antes de cada actualización manual o empaquetada, guarda copia de:

```text
plugins.ini
*.amxx reemplazados
*.cfg reemplazados
```

Para desinstalar el anticheat base:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Los plugins experimentales posteriores pueden requerir eliminación manual de `plugins.ini` y del directorio `plugins`.

## 17. Checklist final de instalación estable

```text
[ ] exactamente un Weapon Comedy actual cargado
[ ] hldm_hornet_policy activado
[ ] hldm_hornet_fix desactivado
[ ] hldm_weaponlab_manage_hornets = 0
[ ] lanzagranadas MP5 stock para jugadores normales
[ ] Python usa zero-entity scatter
[ ] Egon Factory se activa solo para weapon id 10
[ ] addbot desactivado sin bot-DLL
[ ] monstruos nativos runtime desactivados
[ ] amxx plugins sin bad load
[ ] smoke test MP5/RPG/Hornet/Python/Crossbow/Egon superado
```

Solo después de esto conviene devolver el servidor a su estado natural: varias décadas de código GoldSrc fingiendo que la causalidad es una preferencia estética.