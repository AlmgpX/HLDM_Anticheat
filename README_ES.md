# HLDM Anticheat / Chaos Server

[Русский](README.md) | [English](README_EN.md) | **Español**

Un conjunto del lado del servidor para Half-Life Deathmatch / GoldSrc que combina anticheat conductual, herramientas de administración, modos silenciosos para clientes marcados y mutaciones de armas deliberadamente absurdas.

El proyecto funciona del lado del servidor. No escanea procesos del cliente, no modifica archivos ni teclas del cliente y no requiere un mod cliente separado. Los castigos y efectos de armas ocurren dentro de la partida.

## Arquitectura actual

Capa base:

- `hldm_detector.amxx` observa `usercmd`, ángulos de mira, visibilidad y disparos del lado del servidor;
- `hldm_trap.amxx` aplica una trampa manualmente, por SteamID o automáticamente después de una puntuación sostenida del detector;
- `hldm_admin_tools.amxx` y `hldm_runtime_guard.amxx` proporcionan herramientas locales de administración, ESP/x-ray, menús y modos de protección;
- módulos opcionales (`hldm_chaos`, `hldm_silent_misery`, `hldm_leader_curse`, `hldm_meat_demon`, la capa de frases Jungian, etc.) añaden castigos y efectos cómicos separados.

Capa actual de armas:

- `hldm_weapon_comedy.amxx` — Python/revólver, Gauss y humor general de fallos de fábrica;
- `hldm_weapon_lab.amxx` — quiet modes, tripmine, oscilación del RPG, lógica de snarks y otras mutaciones;
- `hldm_weapon_payloads.amxx` — payloads retrasados para satchel, granada de mano y virotes reales de ballesta;
- `hldm_hornet_policy.amxx` — único propietario actual del ciclo de vida/touch/límite de hornets normales;
- `hldm_egon_factory.amxx` — bromas del “aspirador autodestructivo” dirigidas únicamente a Egon;
- `hldm_population_manager.amxx` — cálculo de población de bots y una capa experimental de monstruos, con las funciones runtime peligrosas desactivadas por defecto.

## Reglas actuales de estabilidad

Después de varias lecciones muy visuales impartidas por GoldSrc, el proyecto sigue reglas estrictas:

1. **Un tipo de entidad, un propietario runtime principal.** El touch/lifetime/límite de hornets lo controla `hldm_hornet_policy`.
2. El viejo `hldm_hornet_fix` debe permanecer desactivado: `hldm_hornetfix_enabled "0"`.
3. `hldm_weaponlab_manage_hornets "0"`: Weapon Lab no debe borrar ni retemporizar los mismos hornets en paralelo.
4. El lanzagranadas secundario del MP5 queda stock para jugadores normales. No se reemplaza por cohetes ni recibe payloads adicionales.
5. Python/revólver ya no crea 16 entidades nativas `crossbow_bolt`. Usa 16 trazadores hitscan sin entidad persistente, evitando que un disparo se convierta en 16 explosiones y 48 snarks.
6. `monster_zombie` / `monster_headcrab` nativos no se pueden crear de forma segura con `DLLFunc_Spawn` tardío después de cargar el mapa: la game DLL intenta precachear sonidos y puede provocar `Host_Error`. Por eso el spawn runtime de monstruos está desactivado.
7. Las llamadas automáticas `addbot` permanecen desactivadas hasta instalar un bot-DLL real compatible con ParaBot que proporcione ese comando.
8. El recoil de Python y Gauss tiene un solo propietario: `hldm_weapon_comedy`; Weapon Lab no debe añadir un segundo impulso.
9. `hldm_weaponlab_snark_max "30"` permite realmente 30 snarks y ya no queda limitado internamente a 24.

## Comportamiento actual de armas

### Hornet Gun

- máximo 10 hornets activos por propietario;
- el 11.º se elimina inmediatamente y no hace explotar al más antiguo;
- tocar el mundo no tiene por qué matar al hornet: puede continuar/rebotar;
- golpear un objetivo vivo provoca una mini explosión;
- los hornets supervivientes explotan por temporizador antes del borrado silencioso stock de GoldSrc;
- los touches repetidos con el mundo se limitan para evitar tormentas de eventos cuando una entidad queda atrapada en geometría.

### Python / revólver

Comportamiento actual de `Weapon Comedy 2.4.0`:

- el disparo nativo de Python se conserva para munición, sonido y animación;
- el **daño PvP exacto nativo se suprime**, por lo que la bala central stock no queda como segundo canal oculto de daño;
- el patrón PvP real lo producen 16 trazas hitscan visuales con dispersión tipo escopeta;
- el revólver no crea entidades nativas `crossbow_bolt`;
- cada traza hace 3 de daño por defecto;
- el recoil y el self-damage pertenecen solo a Weapon Comedy;
- Weapon Lab ya no añade un segundo impulso de recoil a Python;
- la ballesta real sigue separada y conserva su propio payload.

### Lanzagranadas del MP5

Completamente stock para jugadores normales:

- una granada de contacto normal;
- sin cohetes dobles;
- sin hornets extra;
- sin cooldown de Weapon Comedy.

Si un jugador está marcado con `QUIET_BETRAYAL`, su granada puede dirigirse gradualmente de vuelta al propietario. Es una regla de castigo silencioso, no una mutación global del MP5.

### RPG

Se usa el cohete stock normal. No se crean cohetes adicionales.

- algunos cohetes reciben una ligera oscilación de “estabilizador defectuoso”;
- el cohete de un jugador con `QUIET_BETRAYAL` puede girar de vuelta hacia su propietario;
- las frases `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` proceden solo del banco RPG/cohete.

### Gauss

- Weapon Lab ya no añade su antiguo recoil separado hacia atrás;
- el recoil secundario pertenece a Weapon Comedy y termina bruscamente hacia abajo o hacia un lado aleatorio;
- los mensajes proceden solo del banco Gauss/magnético, nunca del RPG o Egon.

### Egon

Las bromas del aspirador viven en el plugin separado `hldm_egon_factory.amxx` y se enrutan estrictamente solo al weapon id `10`.

El MP5 tiene otro weapon id y no debe activar mensajes como:

```text
SELF-DESTRUCT VACUUM CLEANER
MADE IN CHINA VACUUM TECHNOLOGY
MADI EN INDIA BEAM CALIBRATION
```

### Granada de mano / satchel / ballesta

- la granada de mano puede liberar hornets guiados con retraso después de la explosión stock;
- la granada de contacto del MP5 no recibe ese payload;
- los snarks creados por satchel permanecen ocultos/invulnerables durante la explosión y se liberan después de un retraso;
- el impacto de un virote real de ballesta recibe su propia mini explosión y payload retrasado de snarks.

## Quiet modes

`hldm_weapon_lab` proporciona modos silenciosos del lado del servidor sin avisar al objetivo:

```text
amx_quiet #USERID damage
amx_quiet #USERID misfire
amx_quiet #USERID betrayal
amx_quiet #USERID drift
amx_quiet #USERID all
amx_quiet #USERID clear
amx_quiet_status
```

Efectos principales:

- `damage` — reduce fuertemente el daño saliente;
- `misfire` — suprime parte de los inputs primary/secondary;
- `betrayal` — algunas entidades projectile/grenade regresan al propietario;
- `drift` — añade un pequeño punch-angle drift del lado del servidor.

Los comandos administrativos requieren los permisos correspondientes de AMX Mod X.

## Inicio rápido

Instrucciones detalladas: [docs/INSTALL_ES.md](docs/INSTALL_ES.md).

Para el listen-server actual de Steam, el flujo general es:

1. Preparar Metamod + AMX Mod X dentro de `Half-Life\valve`.
2. Copiar los `.amxx` actuales a:

```text
Half-Life\valve\addons\amxmodx\plugins\
```

3. Copiar los `.cfg` a:

```text
Half-Life\valve\addons\amxmodx\configs\plugins\
```

4. Revisar `plugins.ini` y eliminar duplicados obsoletos, por ejemplo varias versiones `hldm_weapon_comedy*.amxx`.
5. Iniciar Half-Life mediante Steam y crear un listen server normal.
6. Después de cargar el mapa ejecutar:

```text
meta list
amxx version
amxx modules
amxx plugins
```

Para la capa de armas también:

```text
amx_weaponcomedy_status
amx_egonfactory_status
amx_hornetpolicy_status
amx_payload_status
```

## Orden relativo recomendado de plugins

El `plugins.ini` completo depende de qué módulos experimentales estén activados, pero el orden relativo crítico es:

```text
hldm_trap.amxx
hldm_detector.amxx
...
hldm_weapon_comedy.amxx
hldm_weapon_lab.amxx
hldm_weapon_payloads.amxx
hldm_population_manager.amxx
hldm_hornet_policy.amxx
hldm_egon_factory.amxx
```

`hldm_hornet_policy` debe cargarse después de otros módulos que puedan ver hornets. No cargues el viejo `hldm_hornet_fix`, o mantenlo desactivado mediante configuración.

## Population Manager

Valores seguros actuales:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

La fórmula objetivo de bots ya existe:

```text
floor((maxplayers - human_reserve) * bot_fraction)
```

Por defecto `human_reserve = 2` y `bot_fraction = 0.50`. Half-Life no incluye bots integrados, por lo que `addbot` requiere un bot-DLL real compatible con ParaBot.

## Configs actuales de la capa de armas

```text
configs/plugins/hldm_weapon_comedy.cfg
configs/plugins/hldm_weapon_lab.cfg
configs/plugins/hldm_weapon_payloads.cfg
configs/plugins/hldm_hornet_policy.cfg
configs/plugins/hldm_egon_factory.cfg
configs/plugins/hldm_population_manager.cfg
```

## CI y compilación

GitHub Actions usa AMX Mod X Compiler `1.10.0.5479`, compila **todos** los `src/*.sma`, rechaza warnings de Pawn y empaqueta todos los `.amxx`, configs y documentación en el artifact de CI.

Comprobación local del contrato:

```text
python tools/check_contract.py
```

## Diagnóstico de crashes

Para un crash del listen-server, guarda el final de la consola **desde el primer error hasta `Server shutdown`**. Las líneas posteriores a `Host_Error` suelen ser síntomas del teardown y no la causa original.

Marcadores especialmente útiles:

```text
Host_Error:
PF_precache_*:
ED_Alloc:
SZ_GetSpace:
Run time error
Invalid entity
```

## Documentación

- [Contrato de comportamiento runtime](docs/BEHAVIOR_CONTRACT_ES.md)
- [Instalación en ruso](docs/INSTALL_RU.md)
- [Installation in English](docs/INSTALL_EN.md)
- [Instalación en español](docs/INSTALL_ES.md)
- [Detector](docs/DETECTOR_RU.md)
- [Plan de pruebas](docs/TEST_PLAN.md)
- [Arquitectura](docs/ARCHITECTURE.md)

## Límites de precisión

Un detector conductual del lado del servidor no puede demostrar matemáticamente el nombre de un cheat concreto ni inspeccionar la memoria de otro proceso. Evalúa patrones observables del lado del servidor. Conviene calibrar primero el detector en modo observe/log y activar castigos automáticos solo después de probar jugadores y mapas reales.

Y como esto sigue siendo GoldSrc, compilar sin errores solo demuestra que el código está sintácticamente vivo. No demuestra que veinte entidades, tres plugins antiguos y una game DLL prehistórica hayan aprendido de repente a respetar la causalidad.