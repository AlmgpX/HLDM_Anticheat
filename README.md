# HLDM Anticheat 1.0

Готовый серверный комплект для обычного Half-Life Deathmatch на GoldSrc:

- `hldm_detector.amxx` наблюдает за серверными `usercmd`, углами прицела, видимостью и выстрелами;
- `hldm_trap.amxx` изолированно применяет ловушку к выбранному или автоматически выявленному клиенту;
- PowerShell-установщики разворачивают Metamod, AMX Mod X, оба плагина, конфиги и launcher;
- GitHub Actions компилирует оба `.sma` официальным AMX Mod X 1.10.0.5479 и собирает готовый ZIP.

Система не сканирует процессы клиента, не меняет его файлы и бинды, не отправляет `client_cmd`, не вызывает краши и не банит. Всё происходит внутри матча. Читеру становится плохо именно в игре, а не на чужом компьютере. Неожиданно цивилизованный способ для проекта, посвящённого игровому аду.

## Что ловит детектор

Детектор накапливает score по независимым сигналам:

- большой snap-поворот с немедленным выстрелом в игрока;
- реакция на впервые видимую цель быстрее заданного порога;
- быстрое переключение выстрелов между разными целями;
- невозможные углы `usercmd`;
- нестандартные однопиксельные player-модели обрабатываются отдельным model guard ловушки.

По умолчанию одиночное событие недостаточно. Для автоматического применения нужны минимум два типа сигнала, минимум пять событий и общий score `100`.

## Что делает ловушка

Только для помеченного клиента:

- уменьшает исходящий урон;
- увеличивает входящий урон;
- иногда съедает прыжок, primary fire и secondary fire;
- кратко инвертирует стрейф;
- чередует `SOFT`, ложное `RECOVERY` и `HARD`;
- показывает персональные диагностические HUD-сообщения;
- сохраняет валидный SteamID/ValveID в nVault;
- заменяет нестандартную модель на штатную.

Остальные игроки сохраняют обычные урон, ввод и физику. Глобально действует только явно включённый model guard.

## Самый быстрый запуск на уже установленной Steam-версии

Открой PowerShell в распакованном пакете:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RconPassword "СЮДА_СЛОЖНЫЙ_ПАРОЛЬ" `
  -Hostname "HLDM Anticheat Trap" `
  -Port 27015 `
  -MaxPlayers 16 `
  -OpenFirewall
```

Скрипт создаёт:

```text
Half-Life\run_hldm_anticheat_server.bat
```

Запусти этот `.bat`.

## Чистый отдельный сервер через SteamCMD

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\install_fresh_hlds_windows.ps1 `
  -ServerRoot "E:\HLDM_Server" `
  -RconPassword "СЮДА_СЛОЖНЫЙ_ПАРОЛЬ" `
  -Hostname "HLDM Anticheat Trap" `
  -Port 27015 `
  -MaxPlayers 16 `
  -OpenFirewall `
  -StartServer
```

Скрипт устанавливает HLDS AppID 90 через SteamCMD, затем Metamod, AMX Mod X и оба плагина.

## Стандартная GoldSrc-сборка вне Steam

`setup_hldm_server_windows.ps1` работает с обычной структурой, где в корне находятся:

```text
hlds.exe
valve\
```

Специальных инструкций по крякам и обходу Steam здесь нет. Для `STEAM_ID_LAN`/`VALVE_ID_LAN` автоматическая ловушка действует в текущем подключении, но постоянная запись в nVault намеренно не создаётся.

## Проверка после запуска

В серверной консоли:

```text
meta list
amxx version
amxx modules
amxx plugins
amx_ac_status
amx_trap_list
```

Оба плагина должны иметь статус `running`:

```text
hldm_trap.amxx
hldm_detector.amxx
```

Проверка связи детектора с ловушкой:

```text
status
amx_ac_testtrap #17
amx_trap_list
amx_untrap #17
```

`#17` является серверным `userid`, а не номером слота.

## Команды детектора

```text
amx_ac_status
amx_ac_status #17
amx_ac_reset #17
amx_ac_reset @all
amx_ac_mode 0
amx_ac_mode 1
amx_ac_mode 2
amx_ac_testtrap #17
```

Режимы:

```text
0 = выключен
1 = наблюдение и лог без автоматической ловушки
2 = автоматическое применение ловушки
```

## Команды ловушки

```text
amx_trap #17
amx_untrap #17
amx_trap_id STEAM_0:1:12345678
amx_untrap_id STEAM_0:1:12345678
amx_trap_list
amx_trap_stop
amx_trap_start
```

Все административные команды требуют флаг `l` (`ADMIN_RCON`).

## «Скелеты» и однопиксельные модели

По умолчанию нестандартное значение `model` заменяется на `gordon`, а клиент автоматически становится целью:

```cfg
hldm_trap_force_standard_models "1"
hldm_trap_auto_trap_custom_models "1"
hldm_trap_custom_model_threshold "1"
```

Только замена модели без ловушки:

```cfg
hldm_trap_auto_trap_custom_models "0"
```

## Логи

Подробные события детектора:

```text
valve\addons\amxmodx\logs\hldm_anticheat_events.log
```

Состояние целей ловушки сохраняется в nVault для постоянных SteamID/ValveID.

## Конфиги

```text
valve\addons\amxmodx\configs\plugins\hldm_detector.cfg
valve\addons\amxmodx\configs\plugins\hldm_trap.cfg
```

Подробности:

- `docs/INSTALL_RU.md`
- `docs/DETECTOR_RU.md`
- `docs/TEST_PLAN.md`
- `docs/ARCHITECTURE.md`

## Границы достоверности

Серверный поведенческий детектор не может математически доказать название чит-программы и не видит память клиента. Он выявляет повторяющиеся машинные паттерны и применяет ловушку только после накопления нескольких сигналов. Первую калибровку разумно провести в режиме `1`, затем включить режим `2`.

## Разработка

```text
python tools/check_contract.py
```

CI проверяет Python, синтаксис всех PowerShell-скриптов, компилирует оба Pawn-плагина без предупреждений и собирает установочный пакет. Код с клиентскими командами, киком или баном блокируется контрактом.
