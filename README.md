# HLDM Anticheat / Trap

Серверный AMX Mod X-плагин для обычного Half-Life Deathmatch. Непомеченные игроки получают ванильные физику, ввод и урон. Для выбранной цели сервер включает отдельное состояние: ослабляет исходящий урон, усиливает входящий, иногда съедает первичную/вторичную атаку и прыжок, кратко переворачивает стрейф и чередует наказание с ложным восстановлением.

Плагин не отправляет консольные команды на клиент, не меняет его файлы и бинды, не вызывает краши и не действует за пределами игрового соединения. Унижение остаётся игровым, а не превращается в унылый slowhack из эпохи Internet Explorer 6.

## Текущий статус: 0.2.0

Работает в коде:

- `amx_trap <name|#userid|SteamID>` и `amx_untrap` для подключённых клиентов;
- `amx_trap_id <SteamID>` и `amx_untrap_id` для постоянной цели, даже когда она офлайн;
- сохранение целей через nVault;
- защита администраторов, запрет случайного self-target и ботов;
- серверное изменение урона через Ham Sandwich;
- изменение только текущего `usercmd` помеченной цели через Fakemeta;
- независимые фазы `SOFT -> RECOVERY -> HARD`;
- персональный HUD, видимый только цели;
- глобальная замена нестандартных player-моделей на штатную;
- автоматическое включение ловушки за запрещённую custom-модель;
- аварийные команды `amx_trap_stop` / `amx_trap_start`;
- GitHub Actions-компиляция и готовый пакет установки;
- статический контракт, запрещающий клиентские команды и бан/кик из этого проекта.

Пока **не реализовано**, поэтому README не изображает победу силой типографики:

- надёжный скоринг aim/snap/triggerbot;
- персональные decoy-сущности через `FM_AddToFullPack`;
- fake-client-палач;
- подтверждённый smoke test на живом HLDS с двумя клиентами.

## Требования

- HLDS или ReHLDS с модом `valve`;
- Metamod;
- AMX Mod X 1.9+;
- модули `fakemeta`, `hamsandwich`, `nvault`.

Целевая CI-версия: AMX Mod X `1.10.0.5479`.

## Быстрый запуск

1. Собрать `src/hldm_trap.sma` или скачать artifact GitHub Actions.
2. Положить `hldm_trap.amxx` в `valve/addons/amxmodx/plugins/`.
3. Добавить `hldm_trap.amxx` в `valve/addons/amxmodx/configs/plugins.ini`.
4. Положить конфиг в `valve/addons/amxmodx/configs/plugins/hldm_trap.cfg`.
5. Перезапустить сервер или сменить карту.
6. Проверить `amxx plugins`, `amxx modules` и серверный лог.

Автоматическая установка на Windows:

```powershell
.\tools\build_windows.ps1 -AmxxRoot "E:\SteamLibrary\steamapps\common\Half-Life\valve"
.\deploy\install_windows.ps1 -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Подробности: `docs/INSTALL_RU.md`.

## Команды

Все команды требуют флаг `l` (`ADMIN_RCON`).

```text
status
amx_trap #17
amx_trap_list
amx_untrap #17

amx_trap_id STEAM_0:1:12345678
amx_untrap_id STEAM_0:1:12345678

amx_trap_stop
amx_trap_start
```

`#17` является серверным `userid`, а не номером клиентского слота.

## Custom-модели и «скелеты»

По умолчанию любое нестандартное значение `model` заменяется на `gordon`, а клиент автоматически становится целью ловушки после первого отказа:

```cfg
hldm_trap_force_standard_models "1"
hldm_trap_auto_trap_custom_models "1"
hldm_trap_custom_model_threshold "1"
```

Чтобы только заменять модель без автоматического наказания:

```cfg
hldm_trap_auto_trap_custom_models "0"
```

## Инвариант обычного сервера

Для непомеченного клиента обработчики урона и `FM_CmdStart` завершаются ранним выходом. Глобально действует только явно включённая политика стандартных player-моделей. Она отключается отдельно либо общим аварийным выключателем.

## Разработка

```text
python tools/check_contract.py
```

В `main` должно попадать только то, что прошло компиляцию и smoke test. Экспериментальные детекторы, decoy-сущности и боты идут отдельными ветками и PR. Продакшен и так достаточно часто используется как бесплатный полигон человеческой самоуверенности.
