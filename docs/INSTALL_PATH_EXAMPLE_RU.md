# Пример для текущей Steam-папки

Обнаруженная папка Half-Life:

```text
E:\SteamLibrary\steamapps\common\Half-Life
```

В ней присутствуют `hlds.exe` и папка `valve`, поэтому отдельная установка через SteamCMD не нужна.

Полная установка сервера, античита, ловушек, локального админского оверлея и биндов:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\deploy\setup_hldm_complete_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -AdminSteamId "STEAM_0:1:12345678" `
  -RconPassword "CHANGE_THIS_PASSWORD" `
  -Hostname "HLDM Anticheat Trap" `
  -Port 27015 `
  -MaxPlayers 16 `
  -OpenFirewall `
  -StartServer
```

Если основной сервер уже установлен, достаточно добавить админские инструменты:

```powershell
.\deploy\install_admin_tools_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -AdminSteamId "STEAM_0:1:12345678"
```
