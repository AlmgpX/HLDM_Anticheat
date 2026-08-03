# Установка HLDM Anticheat на Windows

## Готовая цепочка

```text
HLDS/ReHLDS -> Metamod-P -> AMX Mod X -> hldm_trap.amxx -> hldm_detector.amxx
```

Порядок двух плагинов важен: ловушка загружается раньше детектора, чтобы автоматическая команда `amx_trap` уже была зарегистрирована.

## Вариант A: установленная Steam-версия Half-Life

Распакуй release/CI-пакет и открой PowerShell в его корне:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RconPassword "СЛОЖНЫЙ_ПАРОЛЬ" `
  -Hostname "HLDM Anticheat Trap" `
  -Port 27015 `
  -MaxPlayers 16 `
  -OpenFirewall
```

Скрипт:

- проверяет наличие `hlds.exe` и `valve`;
- при необходимости скачивает Metamod-P и AMX Mod X 1.10.0.5479;
- меняет `liblist.gam` на загрузку Metamod и создаёт резервную копию;
- добавляет AMX Mod X в `addons/metamod/plugins.ini`;
- устанавливает оба `.amxx` и оба конфига;
- добавляет плагины в `plugins.ini` в правильном порядке;
- создаёт `hldm_anticheat_server.cfg`;
- создаёт `run_hldm_anticheat_server.bat`;
- опционально открывает UDP-порт в Windows Firewall.

Запуск:

```text
Half-Life\run_hldm_anticheat_server.bat
```

## Вариант B: чистый отдельный HLDS через SteamCMD

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\install_fresh_hlds_windows.ps1 `
  -ServerRoot "E:\HLDM_Server" `
  -RconPassword "СЛОЖНЫЙ_ПАРОЛЬ" `
  -Hostname "HLDM Anticheat Trap" `
  -Port 27015 `
  -MaxPlayers 16 `
  -OpenFirewall `
  -StartServer
```

Установщик скачивает SteamCMD, устанавливает/обновляет HLDS AppID 90 с модом `valve`, затем вызывает основной setup-скрипт.

## Вариант C: стандартная GoldSrc-папка вне Steam

Основной setup-скрипт не требует, чтобы путь находился внутри `SteamLibrary`. Требуется обычная структура:

```text
<HalfLifeRoot>\hlds.exe
<HalfLifeRoot>\valve\
```

Запуск тот же:

```powershell
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "D:\Games\Half-Life" `
  -RconPassword "СЛОЖНЫЙ_ПАРОЛЬ"
```

Проект не содержит кряков, эмуляторов SteamID и инструкций по обходу Steam. Для LAN-ID детектор и ловушка работают в текущей сессии, но nVault не сохраняет цель навсегда.

## Проверка после запуска

В консоли сервера:

```text
meta list
amxx version
amxx modules
amxx plugins
```

Нужны модули:

```text
Fakemeta
Ham Sandwich
nVault
```

Ожидаемые плагины:

```text
hldm_trap.amxx      running
hldm_detector.amxx  running
```

Проверка интеграции:

```text
status
amx_ac_testtrap #USERID
amx_trap_list
amx_untrap #USERID
```

Проверка детектора:

```text
amx_ac_status
amx_ac_mode 1
amx_ac_mode 2
```

## Конфиги

```text
valve\addons\amxmodx\configs\plugins\hldm_trap.cfg
valve\addons\amxmodx\configs\plugins\hldm_detector.cfg
```

Проверка загрузки cvar:

```text
hldm_trap_outgoing_scale
hldm_trap_auto_trap_custom_models
hldm_ac_mode
hldm_ac_auto_threshold
hldm_ac_minimum_categories
```

## Администратор AMX Mod X

Команды требуют флаг `l` (`ADMIN_RCON`). Добавь свой SteamID в:

```text
valve\addons\amxmodx\configs\users.ini
```

Пример:

```text
"STEAM_0:1:12345678" "" "abcdefghijklmnopqrstu" "ce"
```

После изменения выполни `amx_reloadadmins` или перезапусти сервер.

## Ручная компиляция

Положи оба исходника в:

```text
valve\addons\amxmodx\scripting\
```

Затем:

```powershell
amxxpc.exe hldm_trap.sma
amxxpc.exe hldm_detector.sma
```

Готовые файлы:

```text
hldm_trap.amxx
hldm_detector.amxx
```

CI делает то же официальным AMX Mod X Compiler 1.10.0.5479.

## Откат

Удалить оба плагина и конфиги, оставив Metamod и AMX Mod X:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Удалить также nVault, логи и launcher:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RemoveVault `
  -RemoveLogs `
  -RemoveLauncher
```

Резервные копии `liblist.gam` и `plugins.ini` setup-скрипт не удаляет. Это полезнее, чем уверенность человека, который нажал Enter и внезапно вспомнил о последствиях.
