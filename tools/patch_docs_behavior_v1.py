from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing anchor: {label}")
    return text.replace(old, new, 1)


# README RU
p = Path("README.md")
t = p.read_text(encoding="utf-8")
t = t.replace("Текущая версия `Weapon Comedy 2.3.0`:", "Текущая версия `Weapon Comedy 2.4.0`:", 1)
t = replace_once(
    t,
    '- 11-я не взрывает старейшую, а просто не сохраняется как дополнительная активная пчела;\n',
    '- 11-я немедленно удаляется и не взрывает старейшую;\n',
    "RU hornet 11th wording",
)
t = replace_once(
    t,
    '''- 16 визуальных hitscan-трассеров с дробовым разбросом;
- никаких настоящих `crossbow_bolt` от револьвера;
- configurable pellet damage;
- физическая/визуальная отдача;
- небольшое самоповреждение владельца, по умолчанию нелетальное;
- обычный настоящий арбалет остаётся отдельным оружием и сохраняет свой payload.
''',
    '''- штатный Python shot сохраняется для расхода патрона, звука и анимации;
- точный штатный **PvP damage подавляется**, поэтому центральная штатная пуля не остаётся скрытым вторым каналом урона;
- фактический PvP-паттерн дают 16 визуальных hitscan-трассеров с дробовым разбросом;
- никаких настоящих `crossbow_bolt` от револьвера;
- по умолчанию каждая трасса наносит 3 damage;
- физическая/визуальная отдача и self-damage принадлежат только Weapon Comedy;
- Weapon Lab больше не добавляет второй Python recoil;
- обычный настоящий арбалет остаётся отдельным оружием и сохраняет свой payload.
''',
    "RU Python behavior",
)
t = replace_once(
    t,
    '''- заводские сообщения `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` и аналогичные могут появляться как комедийный слой.

### Egon
''',
    '''- заводские сообщения `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` и аналогичные берутся только из RPG/rocket bank.

### Gauss

- Weapon Lab больше не добавляет старый отдельный backward recoil;
- secondary recoil принадлежит Weapon Comedy и переводится резко вниз либо в случайную боковую сторону;
- сообщения берутся только из Gauss/magnetic bank, а не из RPG или Egon.

### Egon
''',
    "RU Gauss section",
)
t = replace_once(
    t,
    '7. Автоматический `addbot` выключен, пока реально не установлен ParaBot или другой bot-DLL, предоставляющий эту команду.\n',
    '7. Автоматический `addbot` выключен, пока реально не установлен ParaBot или другой bot-DLL, предоставляющий эту команду.\n'
    '8. Python и Gauss recoil имеют одного владельца: `hldm_weapon_comedy`; Weapon Lab не должен добавлять второй импульс.\n'
    '9. `hldm_weaponlab_snark_max "30"` реально допускает 30 snark и больше не обрезается внутренним clamp до 24.\n',
    "RU stability additions",
)
t = replace_once(
    t,
    '- [Установка на русском](docs/INSTALL_RU.md)\n',
    '- [Контракт поведения](docs/BEHAVIOR_CONTRACT_RU.md)\n- [Установка на русском](docs/INSTALL_RU.md)\n',
    "RU behavior contract link",
)
p.write_text(t, encoding="utf-8", newline="\n")


# README EN
p = Path("README_EN.md")
t = p.read_text(encoding="utf-8")
t = t.replace("Current `Weapon Comedy 2.3.0` behavior:", "Current `Weapon Comedy 2.4.0` behavior:", 1)
t = replace_once(
    t,
    '- the 11th does not explode the oldest hornet;\n',
    '- the 11th is immediately removed and does not explode the oldest hornet;\n',
    "EN hornet 11th wording",
)
t = replace_once(
    t,
    '''- 16 visual hitscan tracers with shotgun-like spread;
- no native `crossbow_bolt` entities are created by the revolver;
- configurable pellet damage;
- physical/visual recoil;
- small owner self-damage, non-lethal by default;
- the real crossbow remains a separate weapon and keeps its own payload behavior.
''',
    '''- the native Python shot remains for ammo consumption, sound and animation;
- exact native **PvP damage is suppressed**, so the center stock bullet is not a hidden second damage channel;
- the actual PvP pattern is produced by 16 visual hitscan traces with shotgun-like spread;
- no native `crossbow_bolt` entities are created by the revolver;
- each trace deals 3 damage by default;
- physical/visual recoil and owner self-damage belong only to Weapon Comedy;
- Weapon Lab no longer adds a second Python recoil impulse;
- the real crossbow remains separate and keeps its own payload behavior.
''',
    "EN Python behavior",
)
t = replace_once(
    t,
    '''- factory lines such as `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` can appear as a comedy layer.

### Egon
''',
    '''- factory lines such as `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` come only from the RPG/rocket message bank.

### Gauss

- Weapon Lab no longer adds its old separate backward recoil impulse;
- secondary recoil belongs to Weapon Comedy and resolves sharply downward or toward a random side;
- messages come only from the Gauss/magnetic bank, never from RPG or Egon.

### Egon
''',
    "EN Gauss section",
)
t = replace_once(
    t,
    '7. Automatic `addbot` calls remain disabled until a real ParaBot-compatible bot DLL providing that command is installed.\n',
    '7. Automatic `addbot` calls remain disabled until a real ParaBot-compatible bot DLL providing that command is installed.\n'
    '8. Python and Gauss recoil have one owner: `hldm_weapon_comedy`; Weapon Lab must not add a second impulse.\n'
    '9. `hldm_weaponlab_snark_max "30"` now really allows 30 snarks instead of being internally clamped to 24.\n',
    "EN stability additions",
)
t = replace_once(
    t,
    '- [Russian installation](docs/INSTALL_RU.md)\n',
    '- [Runtime behavior contract](docs/BEHAVIOR_CONTRACT_EN.md)\n- [Russian installation](docs/INSTALL_RU.md)\n',
    "EN behavior contract link",
)
p.write_text(t, encoding="utf-8", newline="\n")


# README ES
p = Path("README_ES.md")
t = p.read_text(encoding="utf-8")
t = t.replace("Comportamiento actual de `Weapon Comedy 2.3.0`:", "Comportamiento actual de `Weapon Comedy 2.4.0`:", 1)
t = replace_once(
    t,
    '- el 11.º no hace explotar al más antiguo;\n',
    '- el 11.º se elimina inmediatamente y no hace explotar al más antiguo;\n',
    "ES hornet 11th wording",
)
t = replace_once(
    t,
    '''- 16 trazadores hitscan visuales con dispersión tipo escopeta;
- el revólver no crea entidades nativas `crossbow_bolt`;
- daño por pellet configurable;
- retroceso físico/visual;
- pequeño daño al propietario, no letal por defecto;
- la ballesta real sigue siendo un arma separada y conserva su propio payload.
''',
    '''- el disparo nativo de Python se conserva para munición, sonido y animación;
- el **daño PvP exacto nativo se suprime**, por lo que la bala central stock no queda como segundo canal oculto de daño;
- el patrón PvP real lo producen 16 trazas hitscan visuales con dispersión tipo escopeta;
- el revólver no crea entidades nativas `crossbow_bolt`;
- cada traza hace 3 de daño por defecto;
- el recoil y el self-damage pertenecen solo a Weapon Comedy;
- Weapon Lab ya no añade un segundo impulso de recoil a Python;
- la ballesta real sigue separada y conserva su propio payload.
''',
    "ES Python behavior",
)
t = replace_once(
    t,
    '''- pueden aparecer frases de fábrica como `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE`.

### Egon
''',
    '''- las frases `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` proceden solo del banco RPG/cohete.

### Gauss

- Weapon Lab ya no añade su antiguo recoil separado hacia atrás;
- el recoil secundario pertenece a Weapon Comedy y termina bruscamente hacia abajo o hacia un lado aleatorio;
- los mensajes proceden solo del banco Gauss/magnético, nunca del RPG o Egon.

### Egon
''',
    "ES Gauss section",
)
t = replace_once(
    t,
    '7. Las llamadas automáticas `addbot` permanecen desactivadas hasta instalar un bot-DLL real compatible con ParaBot que proporcione ese comando.\n',
    '7. Las llamadas automáticas `addbot` permanecen desactivadas hasta instalar un bot-DLL real compatible con ParaBot que proporcione ese comando.\n'
    '8. El recoil de Python y Gauss tiene un solo propietario: `hldm_weapon_comedy`; Weapon Lab no debe añadir un segundo impulso.\n'
    '9. `hldm_weaponlab_snark_max "30"` permite realmente 30 snarks y ya no queda limitado internamente a 24.\n',
    "ES stability additions",
)
t = replace_once(
    t,
    '- [Instalación en ruso](docs/INSTALL_RU.md)\n',
    '- [Contrato de comportamiento runtime](docs/BEHAVIOR_CONTRACT_ES.md)\n- [Instalación en ruso](docs/INSTALL_RU.md)\n',
    "ES behavior contract link",
)
p.write_text(t, encoding="utf-8", newline="\n")


# Installation guides: link contract and expose the new Python safety cvar.
install_specs = [
    (
        "docs/INSTALL_RU.md",
        '[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | [Español](INSTALL_ES.md)\n',
        '[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | [Español](INSTALL_ES.md)\n\nЦелевое поведение: [BEHAVIOR_CONTRACT_RU.md](BEHAVIOR_CONTRACT_RU.md).\n',
    ),
    (
        "docs/INSTALL_EN.md",
        '[Русский](INSTALL_RU.md) | **English** | [Español](INSTALL_ES.md)\n',
        '[Русский](INSTALL_RU.md) | **English** | [Español](INSTALL_ES.md)\n\nTarget runtime behavior: [BEHAVIOR_CONTRACT_EN.md](BEHAVIOR_CONTRACT_EN.md).\n',
    ),
    (
        "docs/INSTALL_ES.md",
        '[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | **Español**\n',
        '[Русский](INSTALL_RU.md) | [English](INSTALL_EN.md) | **Español**\n\nComportamiento runtime objetivo: [BEHAVIOR_CONTRACT_ES.md](BEHAVIOR_CONTRACT_ES.md).\n',
    ),
]

for file_name, nav_old, nav_new in install_specs:
    p = Path(file_name)
    t = p.read_text(encoding="utf-8")
    t = replace_once(t, nav_old, nav_new, f"{file_name} contract link")
    if 'hldm_weaponcomedy_python_suppress_stock_pvp_damage "1"' not in t:
        t = replace_once(
            t,
            'hldm_weaponcomedy_python_self_damage_lethal "0"\n',
            'hldm_weaponcomedy_python_self_damage_lethal "0"\n'
            'hldm_weaponcomedy_python_suppress_stock_pvp_damage "1"\n',
            f"{file_name} Python stock damage cvar",
        )
    p.write_text(t, encoding="utf-8", newline="\n")


# Changelog
p = Path("CHANGELOG.md")
t = p.read_text(encoding="utf-8")
entry = '''# Changelog

## Runtime behavior alignment - 2026-08-08

- Python exact native PvP damage is suppressed while the stock shot still provides ammo, sound and animation; the 16-trace scatter is now the actual PvP damage pattern.
- Python and Gauss duplicate backward recoil were removed from Weapon Lab; Weapon Comedy is the single recoil owner for both.
- Python, RPG and Gauss factory messages are split into separate weapon-specific banks. Egon vacuum text remains isolated in `hldm_egon_factory`.
- Legacy Weapon Lab grenade/RPG hornet touch payload paths were removed; delayed hand-grenade hornets remain owned by `hldm_weapon_payloads`.
- The configured snark cap of 30 is now actually allowed by the internal clamp.
- Hornet Policy now marks tracked hornets so reused GoldSrc edict slots do not inherit stale owner/lifetime state.
- Added Russian, English and Spanish runtime behavior contracts and synchronized installation documentation.

'''
if not t.startswith("# Changelog\n\n## Runtime behavior alignment - 2026-08-08"):
    t = replace_once(t, "# Changelog\n\n", entry, "changelog header")
p.write_text(t, encoding="utf-8", newline="\n")
