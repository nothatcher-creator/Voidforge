#!/usr/bin/env python3
"""Source-tree audit for VOIDFORGE BlockDefinition resources and catalog coverage."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLOCK_ROOT = ROOT / "data/blocks"
CATALOG = BLOCK_ROOT / "block_catalog.tres"
ITEM_ROOT = ROOT / "data/items"
VALID_ID = re.compile(r"^[a-z][a-z0-9_]*$")
BLOCK_ID = re.compile(r'^id\s*=\s*&"([^"]+)"$', re.MULTILINE)
DISPLAY = re.compile(r'^display_name\s*=\s*"([^"]*)"$', re.MULTILINE)
CATEGORY = re.compile(r'^category\s*=\s*&"([^"]+)"$', re.MULTILINE)
DIMS = re.compile(r'^dimensions_cells\s*=\s*Vector3i\((\d+),\s*(\d+),\s*(\d+)\)$', re.MULTILINE)
MASS = re.compile(r'^mass_kg\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
INTEGRITY = re.compile(r'^max_integrity\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
VARIANT_GROUP = re.compile(r'^variant_group\s*=\s*&"([^"]+)"$', re.MULTILINE)
VARIANT_KEY = re.compile(r'^variant_key\s*=\s*&"([^"]+)"$', re.MULTILINE)
PRESENTATION_SHAPE = re.compile(r'^presentation_shape\s*=\s*&"([^"]+)"$', re.MULTILINE)
FUNCTIONAL_TYPE = re.compile(r'^functional_type\s*=\s*&"([^"]+)"$', re.MULTILINE)
THRUST_FORCE = re.compile(r'^thrust_force_n\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
POWER_USE = re.compile(r'^power_use_kw\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
POWER_PRIORITY = re.compile(r'^power_priority\s*=\s*(\d+)$', re.MULTILINE)
POWER_PRODUCTION = re.compile(r'^power_production_kw\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
HEAT_GENERATION = re.compile(r'^heat_generation_kw\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
GYRO_TORQUE = re.compile(r'^gyro_torque_nm\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
BATTERY_CAPACITY = re.compile(r'^battery_capacity_kwh\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
BATTERY_INITIAL = re.compile(r'^battery_initial_charge_fraction\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
BATTERY_MAX_CHARGE = re.compile(r'^battery_max_charge_kw\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
BATTERY_MAX_DISCHARGE = re.compile(r'^battery_max_discharge_kw\s*=\s*([-+0-9.eE]+)$', re.MULTILINE)
THRUST_DIRECTION = re.compile(r'^thrust_direction_local\s*=\s*Vector3i\((-?\d+),\s*(-?\d+),\s*(-?\d+)\)$', re.MULTILINE)
PRESENTATION_MATERIAL = re.compile(r'^presentation_material_id\s*=\s*&"([^"]+)"$', re.MULTILINE)
GRID_VALUES = re.compile(r'^allowed_grid_sizes\s*=\s*Array\[StringName\]\(\[(.*)\]\)$', re.MULTILINE)
STRINGNAME = re.compile(r'&"([^"]+)"')
COST_ITEM = re.compile(r'^item_id\s*=\s*&"([^"]+)"$', re.MULTILINE)
COST_QTY = re.compile(r'^quantity\s*=\s*(\d+)$', re.MULTILINE)
CATALOG_PATH = re.compile(r'path="res://data/blocks/([^"]+\.tres)"')
ITEM_ID = re.compile(r'^id\s*=\s*&"([^"]+)"$', re.MULTILINE)


def main() -> int:
    errors: list[str] = []
    if not CATALOG.exists():
        errors.append("Missing data/blocks/block_catalog.tres")
        return finish(errors, 0)

    block_files = sorted(p for p in BLOCK_ROOT.rglob("*.tres") if p != CATALOG)
    if not block_files:
        errors.append("No block definition resources found.")
        return finish(errors, 0)

    item_ids: set[str] = set()
    for item_path in ITEM_ROOT.rglob("*.tres"):
        if item_path.name == "item_catalog.tres":
            continue
        match = ITEM_ID.search(item_path.read_text(encoding="utf-8"))
        if match:
            item_ids.add(match.group(1))

    seen_ids: dict[str, Path] = {}
    for path in block_files:
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if 'path="res://scripts/blocks/block_definition.gd"' not in text:
            errors.append(f"{rel}: does not reference BlockDefinition script")
            continue
        id_match = BLOCK_ID.search(text)
        name_match = DISPLAY.search(text)
        category_match = CATEGORY.search(text)
        dims_match = DIMS.search(text)
        mass_match = MASS.search(text)
        integrity_match = INTEGRITY.search(text)
        grids_match = GRID_VALUES.search(text)
        if not id_match:
            errors.append(f"{rel}: missing block ID")
            continue
        block_id = id_match.group(1)
        if not VALID_ID.fullmatch(block_id):
            errors.append(f"{rel}: invalid lowercase snake_case ID '{block_id}'")
        if block_id in seen_ids:
            errors.append(f"Duplicate block ID '{block_id}': {seen_ids[block_id].relative_to(ROOT)} and {rel}")
        seen_ids[block_id] = path
        if not name_match or not name_match.group(1).strip():
            errors.append(f"{rel}: display_name is empty or missing")
        if not category_match or not VALID_ID.fullmatch(category_match.group(1)):
            errors.append(f"{rel}: invalid or missing category")
        if not dims_match or any(int(value) <= 0 for value in dims_match.groups()):
            errors.append(f"{rel}: dimensions_cells must be three positive integers")
        try:
            if not mass_match or float(mass_match.group(1)) <= 0:
                errors.append(f"{rel}: mass_kg must be positive")
            if not integrity_match or float(integrity_match.group(1)) <= 0:
                errors.append(f"{rel}: max_integrity must be positive")
        except ValueError:
            errors.append(f"{rel}: invalid physical numeric metadata")
        if not grids_match:
            errors.append(f"{rel}: missing allowed_grid_sizes")
        else:
            grids = STRINGNAME.findall(grids_match.group(1))
            if not grids or len(grids) != len(set(grids)) or any(g not in {"small", "large", "static"} for g in grids):
                errors.append(f"{rel}: invalid/duplicate allowed_grid_sizes")
        is_production = ('data/blocks/structure/' in rel.as_posix() or 'data/blocks/armor/' in rel.as_posix() or 'data/blocks/propulsion/' in rel.as_posix() or ('data/blocks/power/' in rel.as_posix() and not rel.name.startswith('dev_')))
        if is_production:
            variant_group = VARIANT_GROUP.search(text)
            variant_key = VARIANT_KEY.search(text)
            shape = PRESENTATION_SHAPE.search(text)
            presentation_material = PRESENTATION_MATERIAL.search(text)
            if not variant_group or not VALID_ID.fullmatch(variant_group.group(1)):
                errors.append(f"{rel}: production block is missing valid variant_group")
            if not variant_key or not VALID_ID.fullmatch(variant_key.group(1)):
                errors.append(f"{rel}: production block is missing valid variant_key")
            if not shape or shape.group(1) not in {"box", "frame", "beam", "panel", "grating", "wedge", "corner", "seat", "thruster", "gyro", "battery", "reactor"}:
                errors.append(f"{rel}: invalid placeholder presentation_shape")
            if not presentation_material or not VALID_ID.fullmatch(presentation_material.group(1)):
                errors.append(f"{rel}: invalid placeholder presentation_material_id")
        cost_items = COST_ITEM.findall(text)
        quantities = [int(v) for v in COST_QTY.findall(text)]
        if not cost_items or len(cost_items) != len(quantities):
            errors.append(f"{rel}: construction costs are missing or malformed")
        if len(cost_items) != len(set(cost_items)):
            errors.append(f"{rel}: duplicate construction-cost item IDs")
        for item_id in cost_items:
            if item_id not in item_ids:
                errors.append(f"{rel}: construction cost references unknown ItemDB ID '{item_id}'")
        if any(q <= 0 for q in quantities):
            errors.append(f"{rel}: construction cost quantities must be positive")

        priority_match = POWER_PRIORITY.search(text)
        if POWER_USE.search(text):
            try:
                demand_value = float(POWER_USE.search(text).group(1))
            except (ValueError, AttributeError):
                demand_value = 0.0
            if demand_value > 0.0:
                if not priority_match:
                    errors.append(f"{rel}: powered consumer is missing power_priority")
                elif int(priority_match.group(1)) not in {0, 1, 2, 3}:
                    errors.append(f"{rel}: power_priority must be 0..3")
        if 'data/blocks/propulsion/' in rel.as_posix():
            functional = FUNCTIONAL_TYPE.search(text)
            thrust_force = THRUST_FORCE.search(text)
            thrust_direction = THRUST_DIRECTION.search(text)
            if not functional or functional.group(1) != "thruster":
                errors.append(f"{rel}: propulsion block must use functional_type=thruster")
            try:
                if not thrust_force or float(thrust_force.group(1)) <= 0.0:
                    errors.append(f"{rel}: thruster requires positive thrust_force_n")
            except ValueError:
                errors.append(f"{rel}: invalid thrust_force_n")
            if not thrust_direction:
                errors.append(f"{rel}: thruster requires cardinal thrust_direction_local")
            else:
                axis = tuple(int(v) for v in thrust_direction.groups())
                if sum(abs(v) for v in axis) != 1:
                    errors.append(f"{rel}: thrust_direction_local must be one cardinal axis")
            shape = PRESENTATION_SHAPE.search(text)
            material = PRESENTATION_MATERIAL.search(text)
            if not shape or shape.group(1) != "thruster":
                errors.append(f"{rel}: propulsion placeholder must use presentation_shape=thruster")
            if not material or material.group(1) != "propulsion":
                errors.append(f"{rel}: propulsion placeholder must use presentation_material_id=propulsion")
        if 'data/blocks/control/vector_gyro_large.tres' in rel.as_posix():
            functional = FUNCTIONAL_TYPE.search(text)
            gyro_torque = GYRO_TORQUE.search(text)
            shape = PRESENTATION_SHAPE.search(text)
            material = PRESENTATION_MATERIAL.search(text)
            if not functional or functional.group(1) != "gyroscope":
                errors.append(f"{rel}: gyro block must use functional_type=gyroscope")
            try:
                if not gyro_torque or float(gyro_torque.group(1)) <= 0.0:
                    errors.append(f"{rel}: gyroscope requires positive gyro_torque_nm")
            except ValueError:
                errors.append(f"{rel}: invalid gyro_torque_nm")
            if not shape or shape.group(1) != "gyro":
                errors.append(f"{rel}: gyroscope placeholder must use presentation_shape=gyro")
            if not material or material.group(1) != "gyro":
                errors.append(f"{rel}: gyroscope placeholder must use presentation_material_id=gyro")

        if 'data/blocks/propulsion/pulse_thruster_large.tres' in rel.as_posix():
            power_use = POWER_USE.search(text)
            if not power_use or abs(float(power_use.group(1)) - 120.0) > 0.001:
                errors.append(f"{rel}: Pulse Thruster Stage 25 rated demand must be 120 kW")
        if 'data/blocks/control/vector_gyro_large.tres' in rel.as_posix():
            power_use = POWER_USE.search(text)
            if not power_use or abs(float(power_use.group(1)) - 90.0) > 0.001:
                errors.append(f"{rel}: Vector Gyro Stage 25 rated demand must be 90 kW")
        if 'data/blocks/control/pilot_cradle_large.tres' in rel.as_posix():
            power_use = POWER_USE.search(text)
            if not power_use or abs(float(power_use.group(1)) - 6.0) > 0.001:
                errors.append(f"{rel}: Pilot Cradle Stage 25 rated demand must be 6 kW")

        priority_expectations = {
            'data/blocks/control/pilot_cradle_large.tres': 0,
            'data/blocks/control/vector_gyro_large.tres': 1,
            'data/blocks/propulsion/pulse_thruster_large.tres': 2,
            'data/blocks/power/dev_aux_load_large.tres': 3,
        }
        rel_text = rel.as_posix()
        if rel_text in priority_expectations:
            priority = POWER_PRIORITY.search(text)
            expected_priority = priority_expectations[rel_text]
            if not priority or int(priority.group(1)) != expected_priority:
                errors.append(f"{rel}: expected power_priority={expected_priority}")
        if 'data/blocks/power/dev_aux_load_large.tres' in rel_text:
            functional = FUNCTIONAL_TYPE.search(text)
            demand = POWER_USE.search(text)
            if not functional or functional.group(1) != 'auxiliary_load':
                errors.append(f"{rel}: development auxiliary load must use functional_type=auxiliary_load")
            if not demand or abs(float(demand.group(1)) - 60.0) > 0.001:
                errors.append(f"{rel}: development auxiliary load must consume 60 kW")
        if 'data/blocks/power/dev_power_source_large.tres' in rel.as_posix():
            functional = FUNCTIONAL_TYPE.search(text)
            production = POWER_PRODUCTION.search(text)
            if not functional or functional.group(1) != "power_source":
                errors.append(f"{rel}: development source must use functional_type=power_source")
            if not production or abs(float(production.group(1)) - 180.0) > 0.001:
                errors.append(f"{rel}: development source must provide 180 kW")
        if 'data/blocks/power/helix_core_reactor_large.tres' in rel.as_posix():
            functional = FUNCTIONAL_TYPE.search(text)
            production = POWER_PRODUCTION.search(text)
            heat = HEAT_GENERATION.search(text)
            shape = PRESENTATION_SHAPE.search(text)
            material = PRESENTATION_MATERIAL.search(text)
            if not functional or functional.group(1) != "reactor":
                errors.append(f"{rel}: Helix Core Reactor must use functional_type=reactor")
            for match, expected_value, field in [
                (production, 480.0, "power_production_kw"),
                (heat, 145.0, "heat_generation_kw"),
            ]:
                try:
                    if not match or abs(float(match.group(1)) - expected_value) > 0.001:
                        errors.append(f"{rel}: Helix Core Reactor {field} must be {expected_value}")
                except ValueError:
                    errors.append(f"{rel}: invalid Helix Core Reactor {field}")
            if not shape or shape.group(1) != "reactor":
                errors.append(f"{rel}: Helix Core Reactor placeholder must use presentation_shape=reactor")
            if not material or material.group(1) != "power_generation":
                errors.append(f"{rel}: Helix Core Reactor placeholder must use presentation_material_id=power_generation")

        if 'data/blocks/power/flux_reservoir_large.tres' in rel.as_posix():
            functional = FUNCTIONAL_TYPE.search(text)
            capacity = BATTERY_CAPACITY.search(text)
            initial = BATTERY_INITIAL.search(text)
            max_charge = BATTERY_MAX_CHARGE.search(text)
            max_discharge = BATTERY_MAX_DISCHARGE.search(text)
            shape = PRESENTATION_SHAPE.search(text)
            material = PRESENTATION_MATERIAL.search(text)
            if not functional or functional.group(1) != "battery":
                errors.append(f"{rel}: Flux Reservoir must use functional_type=battery")
            checks = [
                (capacity, 60.0, "battery_capacity_kwh"),
                (initial, 0.5, "battery_initial_charge_fraction"),
                (max_charge, 180.0, "battery_max_charge_kw"),
                (max_discharge, 240.0, "battery_max_discharge_kw"),
            ]
            for match, expected_value, field in checks:
                try:
                    if not match or abs(float(match.group(1)) - expected_value) > 0.001:
                        errors.append(f"{rel}: Flux Reservoir {field} must be {expected_value}")
                except ValueError:
                    errors.append(f"{rel}: invalid Flux Reservoir {field}")
            if not shape or shape.group(1) != "battery":
                errors.append(f"{rel}: Flux Reservoir placeholder must use presentation_shape=battery")
            if not material or material.group(1) != "power_storage":
                errors.append(f"{rel}: Flux Reservoir placeholder must use presentation_material_id=power_storage")

    catalog_text = CATALOG.read_text(encoding="utf-8")
    refs = CATALOG_PATH.findall(catalog_text)
    expected = sorted(p.relative_to(BLOCK_ROOT).as_posix() for p in block_files)
    actual = sorted(refs)
    if len(refs) != len(set(refs)):
        errors.append("block_catalog.tres contains duplicate resource paths")
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    if missing:
        errors.append("Catalog is missing block files: " + ", ".join(missing))
    if extra:
        errors.append("Catalog references unknown block files: " + ", ".join(extra))

    return finish(errors, len(block_files))


def finish(errors: list[str], count: int) -> int:
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("VOIDFORGE block database source audit: PASS")
    print(f"Cataloged block definitions: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
