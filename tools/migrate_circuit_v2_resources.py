"""Apply the v2 circuit metadata to the authored cyberware resources."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1] / "resources" / "cyberware"
STARTERS = {
    "active_neural_switch", "combat_synapse_sensor", "combat_synapse_sensor_dash",
    "combat_synapse_sensor_guard", "combat_synapse_sensor_hit",
    "combat_synapse_sensor_kill", "rhythm_pulser",
}
MILITARY = {
    "kill_energy_sink", "momentum_recovery_tendon", "ballistic_takeover_protocol",
    "arc_ballistic_cortex", "instruction_mirror_synapse",
    "omnidirectional_reflection_matrix", "axon_recycler",
}
FORBIDDEN = {
    "trajectory_echo_processor", "inertial_inversion_vertebra",
    "predatory_vestibular_ring", "calamity_flame",
}
MODIFIERS = {"smart_fire", "explosive_magazine", "arc_ballistic_cortex", "trajectory_echo_processor"}
RESTRUCTURERS = {
    "micro_rotor_reflex_bundle", "instruction_mirror_synapse",
    "inertial_inversion_vertebra", "predatory_vestibular_ring", "calamity_flame",
}
SCOPES = {
    "smart_fire": ["weapon_call"], "explosive_magazine": ["weapon_call"],
    "arc_ballistic_cortex": ["weapon_call"], "trajectory_echo_processor": ["weapon_call"],
    "tactical_coprocessor": ["weapon_call"], "guard_coprocessor": ["guard_call"],
    "omnidirectional_reflection_matrix": ["guard_call"],
    "micro_rotor_reflex_bundle": ["remaining_slots"],
    "axon_recycler": ["remaining_slots"],
    "momentum_recovery_tendon": ["whole_round"],
    "instruction_mirror_synapse": ["previous_slot"],
    "inertial_inversion_vertebra": ["whole_round"],
    "predatory_vestibular_ring": ["whole_round"],
    "calamity_flame": ["whole_round", "weapon_call"],
}
CATEGORY_TAGS = {"启动器", "修正器", "生成器", "规则器", "规则件", "攻击修正", "射弹修正", "武器调用", "格挡调用", "剩余块", "热量", "固定回能"}
SPECIAL = {
    "kill_energy_sink": {
        "display_name": '"击杀蓄能罐"',
        "description": '"执行时恢复 12 能量。击杀事件启动时恢复 24 能量。"',
        "circuit_tags": 'PackedStringArray("回能", "击杀")',
    },
    "shock_pulser": {
        "display_name": '"冲击脉冲器"',
        "description": '"执行时使 64 像素内普通敌人失衡 0.35 秒；每枚副本增加 32 像素范围与 0.18 秒持续时间。"',
    },
    "momentum_recovery_tendon": {
        "description": '"执行时立即结束本轮回路并恢复 40 能量。"',
        "circuit_tags": 'PackedStringArray("跳转", "回能")',
    },
}


def set_field(text: str, field: str, value: str) -> str:
    expression = rf"(?m)^{re.escape(field)} = .*?$"
    if re.search(expression, text):
        return re.sub(expression, f"{field} = {value}", text)
    match = re.search(r"(?m)^description = .*?$", text)
    if not match:
        raise ValueError("resource has no description")
    return text[:match.end()] + f"\n{field} = {value}" + text[match.end():]


for old, new in (("kill_heat_sink", "kill_energy_sink"), ("heat_threshold_pulser", "shock_pulser")):
    source, destination = ROOT / f"{old}.tres", ROOT / f"{new}.tres"
    if source.exists() and not destination.exists():
        source.rename(destination)

for path in ROOT.glob("*.tres"):
    module_id = path.stem
    text = path.read_text(encoding="utf-8")
    text = set_field(text, "module_id", f'&"{module_id}"')
    grade = 0 if module_id in STARTERS else 2 if module_id in MILITARY else 3 if module_id in FORBIDDEN else 1
    kind = 0 if module_id in STARTERS else 1 if module_id in MODIFIERS else 3 if module_id in RESTRUCTURERS else 2
    scopes = ", ".join(f'&"{scope}"' for scope in SCOPES.get(module_id, []))
    text = set_field(text, "grade", str(grade))
    text = set_field(text, "circuit_kind", str(kind))
    text = set_field(text, "target_scope", f"Array[StringName]([{scopes}])")
    tags = re.search(r"(?m)^circuit_tags = PackedStringArray\((.*?)\)$", text)
    if tags:
        kept = [tag for tag in re.findall(r'"([^"]+)"', tags.group(1)) if tag not in CATEGORY_TAGS]
        text = set_field(text, "circuit_tags", "PackedStringArray(" + ", ".join(f'"{tag}"' for tag in kept) + ")")
    for field, value in SPECIAL.get(module_id, {}).items():
        text = set_field(text, field, value)
    path.write_text(text, encoding="utf-8")
