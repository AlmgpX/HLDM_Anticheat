# HLDM Anticheat / Chaos Server

**Русский** | [English](README_EN.md) | [Español](README_ES.md)

Серверный комплект для Half-Life Deathmatch на GoldSrc: поведенческий античит, административные инструменты, тихие режимы для помеченных клиентов и набор намеренно абсурдных оружейных мутаций.

Проект полностью работает на серверной стороне. Он не сканирует процессы клиента, не меняет клиентские файлы и бинды и не требует отдельного клиентского мода. Наказания и оружейные эффекты происходят внутри матча.

## Текущая архитектура

Базовый слой:

- `hldm_detector.amxx` анализирует серверные `usercmd`, углы прицела, видимость и выстрелы;
- `hldm_trap.amxx` применяет ловушку вручную, по SteamID или автоматически после устойчивого detector-score;
- `hldm_admin_tools.amxx` и `hldm_runtime_guard.amxx` дают администратору локальные инструменты, ESP/x-ray, меню и защитные режимы;
- дополнительные модули (`hldm_chaos`, `hldm_silent_misery`, `hldm_leader_curse`, `hldm_meat_demon`, Jungian phrase layer и др.) дают отдельные режимы наказания и визуально-комедийные эффекты.

Текущий оружейный слой:

- `hldm_weapon_comedy.amxx` — Python/revolver, Gauss и общие заводские шутки;
- `hldm_weapon_lab.amxx` — quiet modes, tripmine, RPG wobble, snark logic и прочие мутации;
- `hldm_weapon_payloads.amxx` — delayed payload после satchel, ручной гранаты и настоящего арбалета;
- `hldm_hornet_policy.amxx` — единственный актуальный владелец жизненного цикла обычных hornet;
- `hldm_egon_factory.amxx` — сообщения про «самоликвидирующийся пылесос» только для Egon;
- `hldm_population_manager.amxx` — расчёт бот-популяции и экспериментальный слой мобов, причём потенциально опасные функции сейчас выключены по умолчанию.

## Важные текущие правила стабильности

После нескольких очень наглядных уроков от GoldSrc в проекте действуют жёсткие правила:

1. **Один тип сущности — один основной runtime-владелец.** Hornet touch/lifetime/cap сейчас контролирует `hldm_hornet_policy`.
2. Старый `hldm_hornet_fix` должен оставаться выключенным: `hldm_hornetfix_enabled "0"`.
3. `hldm_weaponlab_manage_hornets "0"`: Weapon Lab не должен параллельно удалять те же hornet.
4. MP5 underbarrel для обычного игрока остаётся штатным. Он не заменяется ракетами и не создаёт дополнительный payload.
5. Python/revolver не создаёт 16 настоящих `crossbow_bolt`. Используются 16 zero-entity hitscan-трассеров, поэтому один выстрел не превращается в 16 взрывов и 48 снарков.
6. Native `monster_zombie` / `monster_headcrab` нельзя безопасно создавать через поздний `DLLFunc_Spawn` после загрузки карты: game DLL пытается прекешировать звуки и может сделать `Host_Error`. Поэтому runtime monster spawning выключен.
7. Автоматический `addbot` выключен, пока реально не установлен ParaBot или другой bot-DLL, предоставляющий эту команду.
8. Python и Gauss recoil имеют одного владельца: `hldm_weapon_comedy`; Weapon Lab не должен добавлять второй импульс.
9. `hldm_weaponlab_snark_max "30"` реально допускает 30 snark и больше не обрезается внутренним clamp до 24.

## Что сейчас происходит с оружием

### Hornet Gun

- максимум 10 одновременно живых hornet на владельца;
- 11-я немедленно удаляется и не взрывает старейшую;
- касание мира не обязано убивать hornet: политика позволяет ей продолжить полёт/отскок;
- попадание в живую цель вызывает мини-взрыв;
- оставшаяся hornet взрывается по таймеру до штатного тихого удаления GoldSrc;
- touch обрабатывается с ограничением частоты, чтобы застрявшая в геометрии сущность не устраивала шторм вызовов.

### Python / revolver

Текущая версия `Weapon Comedy 2.4.0`:

- штатный Python shot сохраняется для расхода патрона, звука и анимации;
- точный штатный **PvP damage подавляется**, поэтому центральная штатная пуля не остаётся скрытым вторым каналом урона;
- фактический PvP-паттерн дают 16 визуальных hitscan-трассеров с дробовым разбросом;
- никаких настоящих `crossbow_bolt` от револьвера;
- по умолчанию каждая трасса наносит 3 damage;
- физическая/визуальная отдача и self-damage принадлежат только Weapon Comedy;
- Weapon Lab больше не добавляет второй Python recoil;
- обычный настоящий арбалет остаётся отдельным оружием и сохраняет свой payload.

### MP5 underbarrel

Для обычного игрока полностью штатный:

- одна штатная контактная граната;
- без двойных ракет;
- без дополнительных пчёл;
- без Weapon Comedy cooldown.

Если игрок помечен режимом `QUIET_BETRAYAL`, его граната может постепенно вернуться к владельцу. Это отдельная скрытая логика наказания, а не глобальная мутация MP5.

### RPG

Используется штатная ракета. Дополнительные ракеты не создаются.

- часть ракет получает умеренный «дефект стабилизатора»/wobble;
- для помеченного `QUIET_BETRAYAL` игрока ракета может развернуться обратно;
- заводские сообщения `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` и аналогичные берутся только из RPG/rocket bank.

### Gauss

- Weapon Lab больше не добавляет старый отдельный backward recoil;
- secondary recoil принадлежит Weapon Comedy и переводится резко вниз либо в случайную боковую сторону;
- сообщения берутся только из Gauss/magnetic bank, а не из RPG или Egon.

### Egon

Пылесосные сообщения вынесены в отдельный `hldm_egon_factory.amxx` и жёстко маршрутизируются только на weapon id `10`.

MP5 имеет другой weapon id и не должен вызывать сообщения вроде:

```text
SELF-DESTRUCT VACUUM CLEANER
MADE IN CHINA VACUUM TECHNOLOGY
MADI EN INDIA BEAM CALIBRATION
```

### Hand grenade / satchel / crossbow

- ручная граната после штатного взрыва может выпустить delayed guided hornets;
- MP5 contact grenade этот payload не получает;
- satchel-снарки пережидают собственный взрыв скрытыми/неуязвимыми и выпускаются с задержкой;
- настоящий crossbow impact получает отдельный мини-взрыв и delayed snark payload.

## Quiet modes

`hldm_weapon_lab` поддерживает серверные тихие режимы без сообщения цели:

```text
amx_quiet #USERID damage
amx_quiet #USERID misfire
amx_quiet #USERID betrayal
amx_quiet #USERID drift
amx_quiet #USERID all
amx_quiet #USERID clear
amx_quiet_status
```

Основные эффекты:

- `damage` — очень сильное уменьшение исходящего урона;
- `misfire` — часть primary/secondary нажатий не проходит до оружия;
- `betrayal` — некоторые собственные projectile/grenade сущности возвращаются к владельцу;
- `drift` — небольшой серверный punch-angle drift.

Административные команды требуют соответствующих AMX Mod X прав.

## Быстрый запуск

Подробная инструкция: [docs/INSTALL_RU.md](docs/INSTALL_RU.md).

Для текущего Steam listen-server варианта общая схема такая:

1. Установить/подготовить Metamod + AMX Mod X в `Half-Life\valve`.
2. Скопировать актуальные `.amxx` в:

```text
Half-Life\valve\addons\amxmodx\plugins\
```

3. Скопировать `.cfg` в:

```text
Half-Life\valve\addons\amxmodx\configs\plugins\
```

4. Проверить `plugins.ini` и удалить старые дубли вроде нескольких `hldm_weapon_comedy*.amxx`.
5. Запустить Half-Life через Steam и создать обычный listen server.
6. После загрузки карты выполнить:

```text
meta list
amxx version
amxx modules
amxx plugins
```

Для оружейного слоя дополнительно:

```text
amx_weaponcomedy_status
amx_egonfactory_status
amx_hornetpolicy_status
amx_payload_status
```

## Рекомендуемый относительный порядок модулей

Полный `plugins.ini` зависит от того, какие экспериментальные модули включены, но критические зависимости такие:

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

`hldm_hornet_policy` должен загружаться после остальных модулей, способных видеть hornet. Старый `hldm_hornet_fix` либо не загружай, либо оставляй выключенным конфигом.

## Population Manager

Текущие безопасные значения:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Формула целевого количества ботов уже реализована:

```text
floor((maxplayers - human_reserve) * bot_fraction)
```

По умолчанию `human_reserve = 2`, `bot_fraction = 0.50`. Но Half-Life не содержит встроенных ботов. Для `addbot` нужен реальный ParaBot-совместимый bot-DLL.

## Конфиги текущего оружейного стека

```text
configs/plugins/hldm_weapon_comedy.cfg
configs/plugins/hldm_weapon_lab.cfg
configs/plugins/hldm_weapon_payloads.cfg
configs/plugins/hldm_hornet_policy.cfg
configs/plugins/hldm_egon_factory.cfg
configs/plugins/hldm_population_manager.cfg
```

## CI и сборка

GitHub Actions использует AMX Mod X Compiler `1.10.0.5479`, компилирует **все** `src/*.sma`, запрещает Pawn warnings и складывает все `.amxx`, конфиги и документацию в CI artifact.

Локальная проверка контракта:

```text
python tools/check_contract.py
```

## Диагностика вылетов

При падении listen-server нужен хвост консоли **от первой ошибки до `Server shutdown`**. Последние строки после `Host_Error` часто являются уже следствием аварийного shutdown, а не первопричиной.

Особенно важны сообщения:

```text
Host_Error:
PF_precache_*:
ED_Alloc:
SZ_GetSpace:
Run time error
Invalid entity
```

## Документация

- [Контракт поведения](docs/BEHAVIOR_CONTRACT_RU.md)
- [Установка на русском](docs/INSTALL_RU.md)
- [Installation in English](docs/INSTALL_EN.md)
- [Instalación en español](docs/INSTALL_ES.md)
- [Detector](docs/DETECTOR_RU.md)
- [Test plan](docs/TEST_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)

## Границы достоверности

Поведенческий детектор не может математически доказать название конкретного чит-клиента и не видит память чужого процесса. Он оценивает серверно наблюдаемые паттерны. Поэтому detector лучше сначала калибровать в observe/log режиме, а автоматические наказания включать после проверки реальных игроков и карт.

И, поскольку это GoldSrc: успешная компиляция означает, что код синтаксически жив. Она не означает, что двадцать сущностей, три старых плагина и древний game DLL внезапно научились уважать причинно-следственные связи.