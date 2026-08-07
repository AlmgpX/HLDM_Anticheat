# Changelog

## Runtime behavior alignment - 2026-08-08

- Python exact native PvP damage is suppressed while the stock shot still provides ammo, sound and animation; the 16-trace scatter is now the actual PvP damage pattern.
- Python and Gauss duplicate backward recoil were removed from Weapon Lab; Weapon Comedy is the single recoil owner for both.
- Python, RPG and Gauss factory messages are split into separate weapon-specific banks. Egon vacuum text remains isolated in `hldm_egon_factory`.
- Legacy Weapon Lab grenade/RPG hornet touch payload paths were removed; delayed hand-grenade hornets remain owned by `hldm_weapon_payloads`.
- The configured snark cap of 30 is now actually allowed by the internal clamp.
- Hornet Policy now marks tracked hornets so reused GoldSrc edict slots do not inherit stale owner/lifetime state.
- Added Russian, English and Spanish runtime behavior contracts and synchronized installation documentation.

## 1.0.0 - 2026-08-03

### Автоматическое обнаружение

- Добавлен `hldm_detector.amxx`.
- Реализованы сигналы snap-fire, мгновенной реакции, быстрого переключения целей и невозможных углов.
- Добавлены score с затуханием, минимальное число категорий и событий, пороги alert/auto и cooldown.
- Добавлены административные команды `amx_ac_status`, `amx_ac_reset`, `amx_ac_mode`, `amx_ac_testtrap`.
- Добавлен подробный серверный лог с SteamID/ValveID, IP, userid, ping, loss и измеренным значением.
- Автоматический режим передаёт устойчиво подозрительного клиента плагину ловушки по серверному `userid`.

### Развёртывание

- Добавлен однокомандный установщик для существующей Steam-версии Half-Life.
- Добавлен установщик чистого HLDS через SteamCMD AppID 90.
- Автоматически устанавливаются Metamod-P, AMX Mod X, оба плагина и конфиги.
- Автоматически создаются `server.cfg` overlay, launcher `.bat`, резервные копии и опциональное правило Firewall.
- Поддерживается стандартная структура GoldSrc с `hlds.exe` и папкой `valve`.

### CI и качество

- CI компилирует все `src/*.sma` официальным AMX Mod X 1.10.0.5479 без предупреждений.
- Проверяется синтаксис всех PowerShell-скриптов.
- В artifact входят оба `.amxx`, установочный ZIP, конфиги, документация и deploy-скрипты.
- Контракт проверяет 44 cvar, команды, integration hook и отсутствие клиентских команд, кика и бана.

## 0.2.0 - 2026-08-03

### Исправлено

- Конфиг перенесён в реальный путь `addons/amxmodx/configs/plugins/hldm_trap.cfg`, который использует `AutoExecConfig`.
- Добавлена защита администраторов, self-target и ботов.
- Персистентная цель восстанавливается после завершения авторизации и загрузки админских флагов.
- Сборка и установщик проверяют входные файлы и не оставляют временный `.sma`.
- Удаление больше не перекодирует `plugins.ini` в ASCII.

### Добавлено

- `amx_trap_id`, `amx_untrap_id` для офлайн SteamID.
- `amx_trap_start`, `amx_trap_stop`.
- Сбой вторичной атаки.
- Автоматическая ловушка за запрещённую player-модель.
- Независимый секундный тик фаз.
- Расширенный статический контракт и CI-пакет установки.

## 0.1.0 - 2026-08-03

- Первый каркас ручной ловушки, nVault, урон, `usercmd`, HUD и model guard.
