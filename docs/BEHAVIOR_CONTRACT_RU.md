# Контракт поведения HLDM

[Русский](BEHAVIOR_CONTRACT_RU.md) | [English](BEHAVIOR_CONTRACT_EN.md) | [Español](BEHAVIOR_CONTRACT_ES.md)

Этот файл описывает не историю экспериментов, а то, **как текущая сборка должна вести себя в игре**. Если код, конфиг и README расходятся, этот контракт используется как целевое поведение, а расхождение считается багом.

## Главное правило

Один эффект должен иметь одного основного runtime-владельца. Нельзя одновременно давать двум плагинам удалять одну и ту же projectile-сущность, менять один и тот же recoil или создавать два payload для одного события.

## Владельцы поведения

| Поведение | Владелец | Что не должно вмешиваться |
|---|---|---|
| Hornet cap/touch/lifetime | `hldm_hornet_policy` | `hldm_hornet_fix`, Hornet lifecycle в Weapon Lab |
| Python scatter/recoil/self-damage | `hldm_weapon_comedy` | дополнительный Python recoil из Weapon Lab |
| Gauss recoil vector | `hldm_weapon_comedy` | старый backward recoil из Weapon Lab |
| MP5 underbarrel, обычный игрок | штатный Half-Life | Weapon Comedy и payload-плагины |
| MP5/hand-grenade betrayal | `hldm_weapon_lab` | глобальная замена подствольника |
| Hand-grenade delayed hornets | `hldm_weapon_payloads` | старый pre-blast grenade payload Weapon Lab |
| RPG wobble/betrayal | `hldm_weapon_lab` | создание дополнительных RPG rocket entity |
| RPG/Python/Gauss factory text | `hldm_weapon_comedy` | Egon vacuum text |
| Egon vacuum text | `hldm_egon_factory` | MP5/RPG/Python/Gauss |
| Crossbow impact payload | `hldm_weapon_payloads` | Python scatter projectiles |

## Hornet Gun

- максимум 10 активных hornet на владельца;
- 11-я удаляется без взрыва старейшей;
- касание стены не является автоматическим взрывом;
- живой игрок, монстр или breakable может вызвать взрыв;
- оставшаяся hornet завершается взрывом по lifetime;
- `hldm_hornet_fix` выключен;
- Weapon Lab не управляет hornet lifecycle;
- Hornet Policy помечает отслеживаемые entity собственным marker, чтобы повторно использованный GoldSrc edict index не наследовал owner/time от старой пчелы.

## Python / revolver

Python должен ощущаться как ненадёжный «16-пеллетный револьвер», но не создавать entity storm.

- один штатный Python shot остаётся для расхода патрона, звука и анимации;
- точный штатный PvP damage подавляется;
- фактический дополнительный PvP-паттерн строят 16 hitscan-трасс с дробовым разбросом;
- по умолчанию каждая трасса наносит 3 damage;
- native `crossbow_bolt` не создаются;
- поэтому Python не должен вызывать crossbow explosion/snark payload;
- владелец получает небольшое нелетальное self-damage;
- recoil принадлежит только Weapon Comedy;
- сообщения Python берутся только из Python/revolver factory bank.

## MP5

Primary fire может сохранять отдельные глобальные Weapon Lab-приколы, но **подствольник для обычного игрока штатный**.

- один штатный contact grenade;
- без двойных ракет;
- без Weapon Comedy cooldown;
- без delayed hornet payload;
- без сообщений Egon/vacuum;
- под `QUIET_BETRAYAL` собственная grenade может развернуться обратно к владельцу.

## RPG

- используется одна штатная `rpg_rocket`;
- дополнительные rocket entity не создаются;
- Weapon Lab может дать существующей ракете умеренный wobble;
- `QUIET_BETRAYAL` может вернуть существующую ракету владельцу;
- никакого старого rocket-to-hornet touch payload;
- factory text должен быть только про RPG/rocket, а не про пылесос или Python.

## Gauss

- Weapon Lab не добавляет отдельный backward recoil;
- secondary recoil корректирует только Weapon Comedy;
- итоговый импульс должен быть резко вниз либо в случайную боковую сторону;
- сообщения должны идти только из Gauss/magnetic bank.

## Egon

- vacuum/self-destruct сообщения принадлежат только `hldm_egon_factory`;
- hard gate: weapon id `10`;
- MP5 underbarrel не может вызвать Egon text;
- Weapon Lab может сохранять отдельный gameplay-эффект Egon, например периодический hornet, но это не должно менять маршрутизацию текста.

## Hand grenade / satchel / crossbow

- delayed guided hornets после взрыва принадлежат только ручной гранате;
- MP5 contact grenade их не получает;
- satchel-снарки защищены во время собственного blast и выпускаются с задержкой;
- реальный crossbow bolt получает mini explosion + delayed snarks;
- Python не создаёт реальные crossbow bolt и не должен попадать в эту систему.

## Snarks

- конфиг `hldm_weaponlab_snark_max "30"` должен реально позволять 30, а не быть обрезан внутренним clamp ниже этого значения;
- лимит существует для защиты edict pool от бесконтрольного размножения.

## Population Manager

По умолчанию:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

`addbot` включается только после установки совместимого bot-DLL. Late native spawn `monster_zombie`/`monster_headcrab` не включается, пока не появится безопасная pooled/custom реализация.

## Минимальный smoke test после обновления

1. Python: 6 выстрелов подряд, никаких explosion/snark, 16 трасс, self-damage нелетальный.
2. MP5 alt-fire: одна штатная contact grenade, без rocket/vacuum/hornet payload.
3. RPG: одна штатная ракета, часть слегка виляет, никаких дополнительных rocket entity.
4. Gauss secondary: нет отдельного первоначального backward kick от Weapon Lab.
5. Egon: vacuum text появляется только при Egon.
6. Hornet Gun: максимум 10, 11-я не взрывает старейшую, стены не обязаны взрывать hornet.
7. `amxx plugins`: все актуальные плагины `running`, старые дубли не загружены.
