# Установка HLDM Anticheat / Chaos Server на Windows

[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | [Español](INSTALL_ES.md)

Эта инструкция описывает **текущий полный стек**, а не только ранние `hldm_trap` + `hldm_detector`.

## 1. Что выбрать: listen server или отдельный HLDS

### Рекомендуемый вариант для текущего проекта: Steam listen server

Используется установленная Steam-версия Half-Life. Сервер создаётся из самой игры через `Multiplayer -> Create Server`.

Плюсы:

- хозяин уже находится в матче;
- удобно тестировать плагины на той же машине;
- Steam Friends / Join Game / Invite работают по обычной модели listen-server;
- текущая разработка оружейных и административных модулей в первую очередь проверяется именно здесь.

Типичный путь:

```text
E:\SteamLibrary\steamapps\common\Half-Life
```

### Отдельный HLDS

Подходит для постоянного сервера без запущенного игрового клиента. Репозиторий сохраняет PowerShell-установщик для HLDS AppID 90, но полный экспериментальный набор модулей всё равно нужно сверять с актуальным CI artifact.

## 2. Требуемая цепочка

```text
Half-Life / HLDS
    -> Metamod
        -> AMX Mod X 1.10
            -> HLDM plugins
```

Минимально нужны AMXX-модули:

```text
Fakemeta
Ham Sandwich
nVault
```

Проверка после запуска:

```text
meta list
amxx version
amxx modules
```

## 3. Получение готовых `.amxx`

GitHub Actions компилирует **все** файлы:

```text
src\*.sma
```

официальным AMX Mod X Compiler `1.10.0.5479` и кладёт готовые плагины в CI artifact.

В CI также собирается ZIP с:

```text
addons\amxmodx\plugins\*.amxx
addons\amxmodx\configs\plugins\*.cfg
docs\*.md
```

Это предпочтительнее ручной компиляции, потому что CI запрещает Pawn warnings. GoldSrc и без предупреждений способен удивлять, незачем выдавать ему дополнительное оружие.

## 4. Установка полного стека в Steam Half-Life

Полностью закрой Half-Life перед заменой `.amxx`.

Скопируй плагины в:

```text
<HalfLifeRoot>\valve\addons\amxmodx\plugins\
```

Скопируй конфиги в:

```text
<HalfLifeRoot>\valve\addons\amxmodx\configs\plugins\
```

Для примера:

```text
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\plugins\
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\configs\plugins\
```

## 5. Критически важная очистка старых плагинов

Перед запуском проверь:

```text
valve\addons\amxmodx\configs\plugins.ini
```

Не должно быть одновременно нескольких старых Weapon Comedy, например:

```text
hldm_weapon_comedy.amxx
hldm_weapon_comedy_v2.amxx
hldm_weapon_comedy_v3.amxx
hldm_weapon_comedy_v4.amxx
```

Должна быть **одна актуальная версия**.

То же правило относится к экспериментальным дубликатам других модулей. Наличие старого `.amxx` на диске само по себе не страшно; опасно, когда две версии одновременно перечислены в `plugins.ini` и обе обрабатывают один `Touch`, `Think` или `CmdStart`.

## 6. Рекомендуемый относительный порядок

Полный список зависит от включённых экспериментальных модулей, но основные зависимости:

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

Правила:

- `hldm_trap` раньше `hldm_detector`;
- Weapon Comedy раньше Weapon Lab;
- `hldm_hornet_policy` после остальных модулей, способных видеть hornet;
- старый `hldm_hornet_fix` лучше не загружать вообще. Если он остаётся, `hldm_hornetfix_enabled "0"` обязателен.

## 7. Обязательные текущие настройки стабильности

### Hornet

В `hldm_hornet_policy.cfg`:

```cfg
hldm_hornetpolicy_enabled "1"
hldm_hornetpolicy_max_active "10"
hldm_hornetpolicy_lifetime "3.20"
hldm_hornetfix_enabled "0"
```

В `hldm_weapon_lab.cfg`:

```cfg
hldm_weaponlab_manage_hornets "0"
hldm_weaponlab_rocket_hornets "0"
```

Не включай параллельное управление одной hornet в нескольких плагинах.

### MP5 underbarrel

Для обычных игроков остаётся штатным. Не должно быть старых cvar/версий, которые заменяют secondary fire на двойные ракеты.

Текущий Weapon Comedy не должен содержать старые настройки вроде:

```text
second_rocket
rocket_max_active
rocket_speed
```

относящиеся к прежней экспериментальной замене MP5 underbarrel.

### Python / revolver

Текущая безопасная версия:

```cfg
hldm_weaponcomedy_python_self_damage "4.0"
hldm_weaponcomedy_python_self_damage_lethal "0"
hldm_weaponcomedy_python_pellets "16"
hldm_weaponcomedy_python_pellet_damage "3.0"
hldm_weaponcomedy_python_spread "0.16"
hldm_weaponcomedy_python_range "4096.0"
hldm_weaponcomedy_python_recoil "220.0"
```

Ключевое правило: револьвер не создаёт native `crossbow_bolt`. Все 16 дополнительных «болтов» — визуальные hitscan-трассы без постоянных entity.

### Egon

`hldm_egon_factory.amxx` отвечает только за Egon weapon id `10`.

Проверка:

```text
amx_egonfactory_status
```

MP5 underbarrel не должен вызывать сообщения про пылесос.

### Population Manager

Текущие безопасные значения:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Причины:

- `addbot` не существует без установленного ParaBot/совместимого bot-DLL;
- поздний native spawn `monster_zombie`/`monster_headcrab` может вызвать `PF_precache_sound_I` и `Host_Error`, потому что game DLL пытается прекешировать звук уже после загрузки карты.

Не включай `hldm_population_monsters_enabled 1` в текущей реализации.

## 8. Запуск Steam listen server

После установки Metamod/AMXX и плагинов:

1. Запусти Half-Life через Steam.
2. Открой `Multiplayer`.
3. Выбери `Create Server`.
4. Выбери карту, количество игроков и остальные параметры.
5. Создай сервер.

Если у тебя уже используется подготовленный launcher, запускай его вместо обычного запуска Half-Life.

После загрузки карты открой консоль.

## 9. Первичная проверка

```text
meta list
amxx version
amxx modules
amxx plugins
```

Не должно быть:

```text
bad load
error
unknown
```

у актуальных HLDM-плагинов.

Проверка core:

```text
amx_ac_status
amx_trap_list
```

Проверка оружейного слоя:

```text
amx_weaponcomedy_status
amx_hornetpolicy_status
amx_payload_status
amx_egonfactory_status
```

Проверка quiet modes:

```text
amx_quiet_status
```

## 10. Тест после обновления

После каждой замены оружейных `.amxx` не начинай сразу с десяти минут хаоса. Прогоняй короткий smoke test.

### MP5

```text
10 одиночных alt-fire
несколько удержаний alt-fire
```

Ожидается одна штатная contact grenade на штатное срабатывание, без роя ракет и без Egon/vacuum сообщений.

### RPG

```text
10 одиночных выстрелов
```

Ожидается одна штатная ракета на выстрел. Часть может слегка вилять. Дополнительные ракеты не создаются.

### Hornet Gun

Выпусти несколько серий.

Ожидается:

- не больше 10 активных hornet на владельца;
- 11-я не взрывает старейшую;
- контакт со стеной не обязан уничтожать hornet;
- оставшиеся hornet завершаются контролируемым взрывом по lifetime.

### Python

Проверь:

```text
1 выстрел в стену
6 выстрелов подряд в стену
несколько выстрелов в игрока
```

Ожидается:

- трассеры/искры;
- нет 16 физических crossbow entities;
- нет 16 взрывов;
- нет 48 снарков;
- self-damage не убивает владельца при стандартной настройке.

### Настоящий crossbow

Проверь отдельно, что его собственный impact/payload по-прежнему работает. Это важно: Python больше не должен использовать тот же native entity path.

### Egon

Стреляй Egon несколько раз. Пылесосные сообщения могут появляться только здесь.

## 11. Quiet punishment test

Найди `userid`:

```text
status
```

Пример:

```text
amx_quiet #17 betrayal
```

Проверь ручную гранату, MP5 contact grenade и RPG у **помеченного** клиента. Потом обязательно очисти:

```text
amx_quiet #17 clear
```

`#17` — server userid, не slot index.

## 12. Администратор AMX Mod X

Добавь SteamID в:

```text
valve\addons\amxmodx\configs\users.ini
```

Пример:

```text
"STEAM_0:1:12345678" "" "abcdefghijklmnopqrstu" "ce"
```

После изменения:

```text
amx_reloadadmins
```

или перезапусти сервер.

## 13. Legacy setup-скрипты репозитория

В репозитории остаются:

```text
deploy\setup_hldm_server_windows.ps1
deploy\install_fresh_hlds_windows.ps1
deploy\uninstall_windows.ps1
```

Они полезны для установки базовой цепочки Metamod + AMX Mod X + core anticheat. Но проект вырос сильно быстрее собственных первоначальных установщиков, поэтому **актуальность полного набора плагинов сверяй с CI artifact и `src/*.sma`**.

Базовый setup пример:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RconPassword "СЛОЖНЫЙ_ПАРОЛЬ" `
  -Hostname "HLDM" `
  -Port 27015 `
  -MaxPlayers 16
```

## 14. Ручная компиляция

AMX Mod X Compiler `1.10.0.5479`.

Исходники:

```text
src\*.sma
```

Можно компилировать каждый `.sma` через `amxxpc.exe`. CI делает это автоматически и отклоняет warnings.

Локальный contract check:

```text
python tools/check_contract.py
```

## 15. Диагностика падения

При вылете скопируй консоль **начиная с первой ошибки**, а не только последние две строки.

Особенно важны:

```text
Host_Error:
PF_precache_sound_I:
PF_precache_model_I:
ED_Alloc:
SZ_GetSpace:
Invalid entity
Run time error
```

Пример уже найденной реальной первопричины:

```text
Host_Error: PF_precache_sound_I: 'zombie/claw_strike1.wav'
Precache can only be done in spawn functions
```

Последовавшие после этого `nVault`, `disconnect`, `unload` и `Server shutdown` были уже следствием аварийного завершения.

## 16. Откат

Перед каждым готовым установщиком/ручным обновлением делай backup:

```text
plugins.ini
*.amxx, которые заменяются
*.cfg, которые заменяются
```

Для полного отката базового anticheat можно использовать:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Экспериментальные плагины, добавленные позже, при необходимости удаляются из `plugins.ini` и папки `plugins` вручную.

## 17. Финальный чек-лист стабильной установки

```text
[ ] один актуальный Weapon Comedy
[ ] hldm_hornet_policy включён
[ ] hldm_hornet_fix выключен
[ ] hldm_weaponlab_manage_hornets = 0
[ ] MP5 underbarrel штатный для обычного игрока
[ ] Python использует zero-entity scatter
[ ] Egon Factory срабатывает только на weapon id 10
[ ] addbot выключен без bot-DLL
[ ] runtime native monsters выключены
[ ] amxx plugins без bad load
[ ] smoke test MP5/RPG/Hornet/Python/Crossbow/Egon пройден
```

Вот после этого можно уже устраивать серверу настоящую игровую вакханалию. До этого любая «ещё одна смешная ракета» подозрительно быстро превращается в курс по археологии GoldSrc.