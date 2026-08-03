# Установка на Windows

## 1. Серверная цепочка

Плагин не запускается сам по себе. Нужна цепочка:

```text
HLDS/ReHLDS -> Metamod -> AMX Mod X -> hldm_trap.amxx
```

В серверной консоли проверь:

```text
meta list
amxx version
amxx modules
```

Нужны модули `Fakemeta`, `Ham Sandwich` и `nVault`. Они входят в базовый AMX Mod X и обычно загружаются автоматически по зависимостям плагина.

## 2. Компиляция вручную

Положи `src/hldm_trap.sma` в:

```text
Half-Life\valve\addons\amxmodx\scripting\
```

Запусти `amxxpc.exe hldm_trap.sma`. Готовый `hldm_trap.amxx` появится рядом с исходником.

Сборка из репозитория:

```powershell
.\tools\build_windows.ps1 -AmxxRoot "E:\SteamLibrary\steamapps\common\Half-Life\valve"
```

Результат:

```text
build\hldm_trap.amxx
```

## 3. Установка

```powershell
.\deploy\install_windows.ps1 -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Скрипт:

- проверяет AMXX и собранный `.amxx`;
- копирует плагин;
- копирует AutoExecConfig в `addons/amxmodx/configs/plugins/hldm_trap.cfg`;
- делает резервную копию `plugins.ini`;
- добавляет `hldm_trap.amxx` без дубликатов.

## 4. Проверка после смены карты

```text
amxx plugins
amxx modules
amxx cvars
```

В `amxx plugins` плагин должен иметь статус `running`, а не `bad load`.

Проверка команд:

```text
status
amx_trap_list
amx_trap #USERID
amx_untrap #USERID
```

## 5. Проверка пути конфига

В серверной консоли:

```text
hldm_trap_outgoing_scale
hldm_trap_protect_admins
hldm_trap_auto_trap_custom_models
```

Значения должны совпадать с:

```text
valve\addons\amxmodx\configs\plugins\hldm_trap.cfg
```

Старый путь `configs\hldm_trap.cfg` не используется `AutoExecConfig`.

## 6. Откат

```powershell
.\deploy\uninstall_windows.ps1 -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Удалить также nVault со списком целей:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RemoveVault
```
