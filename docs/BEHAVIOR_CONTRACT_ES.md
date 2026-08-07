# Contrato de comportamiento runtime de HLDM

[Русский](BEHAVIOR_CONTRACT_RU.md) | [English](BEHAVIOR_CONTRACT_EN.md) | **Español**

Este archivo describe cómo **debe comportarse la build actual dentro del juego**. No es una historia de experimentos. Si el código, la configuración y el README se contradicen, este contrato define el comportamiento objetivo y la diferencia se considera un bug.

## Regla principal

Un efecto debe tener un solo propietario runtime principal. Dos plugins no deben borrar simultáneamente el mismo proyectil, aplicar retroceso duplicado al mismo arma ni crear dos payloads para el mismo evento.

## Propiedad del comportamiento

| Comportamiento | Propietario | No debe compartirlo con |
|---|---|---|
| Límite/touch/lifetime de hornet | `hldm_hornet_policy` | `hldm_hornet_fix`, lifecycle de hornets en Weapon Lab |
| Dispersión/recoil/self-damage de Python | `hldm_weapon_comedy` | recoil adicional de Python en Weapon Lab |
| Vector de recoil de Gauss | `hldm_weapon_comedy` | recoil hacia atrás heredado de Weapon Lab |
| Lanzagranadas MP5, jugador normal | Half-Life stock | Weapon Comedy y plugins de payload |
| Betrayal de MP5/granada de mano | `hldm_weapon_lab` | reemplazo global del lanzagranadas |
| Hornets retrasados de granada de mano | `hldm_weapon_payloads` | antiguo payload pre-blast de Weapon Lab |
| Wobble/betrayal del RPG | `hldm_weapon_lab` | creación de cohetes RPG duplicados |
| Texto de fábrica RPG/Python/Gauss | `hldm_weapon_comedy` | texto de aspirador de Egon |
| Texto de aspirador de Egon | `hldm_egon_factory` | MP5/RPG/Python/Gauss |
| Payload de impacto de ballesta | `hldm_weapon_payloads` | proyectiles de dispersión de Python |

## Hornet Gun

- máximo 10 hornets activos por propietario;
- el 11.º se elimina sin hacer explotar al más antiguo;
- tocar geometría del mundo no significa explosión automática;
- jugadores vivos, monstruos y breakables pueden provocar explosión;
- los hornets supervivientes terminan con una explosión por lifetime;
- `hldm_hornet_fix` permanece desactivado;
- Weapon Lab no controla el lifecycle de hornets;
- Hornet Policy marca las entidades seguidas para que un índice edict reutilizado por GoldSrc no herede owner/time de un hornet anterior.

## Python / revólver

Python debe sentirse como un revólver defectuoso de 16 pellets sin crear una tormenta de entidades.

- el disparo nativo de Python se conserva para consumo de munición, sonido y animación;
- el daño PvP exacto del disparo nativo se suprime;
- el patrón real PvP lo producen 16 trazas hitscan con dispersión tipo escopeta;
- cada traza hace 3 de daño por defecto;
- no se crean entidades nativas `crossbow_bolt`;
- por eso Python no debe activar el payload explosion/snark de la ballesta;
- el self-damage del propietario es pequeño y no letal por defecto;
- el recoil pertenece solo a Weapon Comedy;
- los mensajes de Python proceden solo del banco de fábrica Python/revólver.

## MP5

El primary fire puede conservar bromas globales independientes de Weapon Lab, pero **el lanzagranadas permanece stock para jugadores normales**.

- una granada de contacto stock;
- sin cohetes dobles;
- sin cooldown de Weapon Comedy;
- sin payload retrasado de hornets;
- sin mensajes Egon/aspirador;
- con `QUIET_BETRAYAL`, la granada propia puede volver hacia su propietario.

## RPG

- se usa un solo `rpg_rocket` stock;
- no se crean cohetes duplicados;
- Weapon Lab puede añadir un wobble moderado al cohete existente;
- `QUIET_BETRAYAL` puede hacer que el cohete existente vuelva hacia su propietario;
- no existe el antiguo payload touch rocket-to-hornet;
- el texto de fábrica debe ser específico de RPG/cohetes, nunca de aspiradores o Python.

## Gauss

- Weapon Lab no añade un impulso separado de retroceso hacia atrás;
- el recoil secundario lo corrige solo Weapon Comedy;
- el impulso final va bruscamente hacia abajo o hacia un lado aleatorio;
- los mensajes proceden solo del banco Gauss/magnético.

## Egon

- los mensajes vacuum/self-destruct pertenecen solo a `hldm_egon_factory`;
- hard gate: weapon id `10`;
- el lanzagranadas MP5 no puede activar texto de Egon;
- Weapon Lab puede conservar un efecto gameplay separado de Egon, como hornets periódicos, pero no debe afectar al routing de mensajes.

## Granada de mano / satchel / ballesta

- los hornets guiados retrasados después de la explosión stock pertenecen solo a la granada de mano;
- las granadas de contacto MP5 no reciben ese payload;
- los snarks del satchel están protegidos durante su propia explosión y se liberan con retraso;
- un virote real de ballesta recibe mini explosión + snarks retrasados;
- Python no crea virotes reales y nunca debe entrar en ese payload.

## Snarks

- `hldm_weaponlab_snark_max "30"` debe permitir realmente 30 y no quedar limitado internamente a un valor menor;
- el límite existe para proteger el pool de edicts de GoldSrc contra multiplicación sin control.

## Population Manager

Valores por defecto:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Activa `addbot` solo después de instalar un bot-DLL compatible. No actives spawn nativo tardío de `monster_zombie` / `monster_headcrab` hasta disponer de una implementación pooled/custom segura.

## Smoke test mínimo después de actualizar

1. Python: seis disparos, sin explosiones/snarks, 16 trazas, self-damage no letal.
2. MP5 alt-fire: una granada de contacto stock, sin payload rocket/vacuum/hornet.
3. RPG: un cohete stock, algo de wobble, sin cohetes duplicados.
4. Gauss secondary: sin kick inicial separado hacia atrás de Weapon Lab.
5. Egon: texto de aspirador solo con Egon seleccionado.
6. Hornet Gun: límite 10, el 11.º no explota al más antiguo, tocar una pared no implica explosión automática.
7. `amxx plugins`: todos los plugins actuales `running`, sin builds antiguas duplicadas cargadas.
