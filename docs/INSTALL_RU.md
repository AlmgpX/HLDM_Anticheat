# Установка на Windows

## 1. Проверить AMX Mod X

В серверной консоли:

```text
meta list
amxx version
amxx modules
```

Нужны модули `Fakemeta`, `Ham Sandwich` и `nVault`. Обычно они входят в базовый AMX Mod X и подгружаются автоматически по include-зависимостям плагина.

## 2. Компиляция вручную

Положить `src/hldm_trap.sma` в:

```text
Half-Life\valve\addons\amxmodx\scripting\
```

Перетащить файл на `compile.exe` либо запустить `amxxpc.exe`. Результат искать в `scripting\compiled\` или рядом с исходником, в зависимости от способа запуска.

Для автоматической сборки из репозитория:

```powershell
.\tools\build_windows.ps1 -AmxxRoot "E:\SteamLibrary\steamapps\common\Half-Life\valve"
```

## 3. Установка

```powershell
.\deploy\install_windows.ps1 -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Скрипт:

- проверит наличие AMXX;
- скопирует `build\hldm_trap.amxx`;
- скопирует конфиг;
- сделает резервную копию `plugins.ini`;
- добавит строку `hldm_trap.amxx`, если её ещё нет.

## 4. Проверка

После смены карты:

```text
amxx plugins
amxx cvars HLDM Trap
```

Затем:

```text
status
amx_trap #USERID
amx_trap_list
```

## 5. Откат

```powershell
.\deploy\uninstall_windows.ps1 -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```
