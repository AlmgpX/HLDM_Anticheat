# HLDM Weapon Lab 1.0

## Тихие режимы

Открыть меню:

```text
amx_quiet_menu
```

или написать в чат:

```text
/quiet
```

Режимы применяются по SteamID и не показывают цели HUD, чат или публичное объявление:

1. `damage` — исходящий урон умножается на `0.01`.
2. `misfire` — часть primary/secondary нажатий полностью подавляется до отпускания кнопки.
3. `betrayal` — собственные hornet, snark и гранаты возвращаются к владельцу.
4. `drift` — небольшие случайные изменения punch-angle во время стрельбы.
5. `all` — все четыре режима.
6. `clear` — полное снятие.

Прямые команды:

```text
amx_quiet #17 damage
amx_quiet #17 misfire
amx_quiet #17 betrayal
amx_quiet #17 drift
amx_quiet #17 all
amx_quiet #17 clear
amx_quiet_status
```

## Глобальные изменения оружия

- Crowbar: атака даёт короткий рывок; попадание подбрасывает жертву и выбивает мясо.
- Glock: каждый седьмой выстрел выпускает быстрого hornet.
- Python: сильная отдача отбрасывает стрелка назад.
- MP5: каждый десятый выстрел выпускает двух hornet; secondary создаёт небольшой airburst в точке прицела.
- Crossbow: secondary мгновенно взрывает владельца.
- Shotgun: primary и double-shot физически отбрасывают стрелка.
- RPG: ракета при первом столкновении выпускает hornet-рой.
- Gauss: secondary работает как чрезмерный rocket-jump.
- Egon: удержание primary периодически выпускает hornet.
- Hornet gun: hornet обоих режимов взрываются при контакте или завершении жизни; максимум 10 на владельца.
- Hand grenade / grenade entities: перед детонацией выпускают hornet.
- Tripmine: штатный луч остаётся, дополнительно после взведения срабатывает при приближении живого игрока примерно на 200 units.
- Satchel: secondary вылупляет snark из каждой своей заложенной satchel перед штатным подрывом.
- Snark: максимум 6 на владельца; после смерти выпускает hornet и мясо; secondary раз в четыре секунды бросает alpha-snark.

Все значения находятся в `configs/plugins/hldm_weapon_lab.cfg`.
