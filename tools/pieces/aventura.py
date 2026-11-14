"""Juego de piezas «Aventura» (3D articulado): personajes con esqueleto y animaciones de KayKit.

Origen: «KayKit : Adventurers Character Pack (1.0)», de Kay Lousberg (www.kaylousberg.com), licencia CC0:
https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (commit 672074b).

Cada .glb original trae 76 animaciones (3,6 MB). Aquí se dejan solo las que usa el tablero y se reempaqueta el
archivo, que queda en godot/sets/aventura/<personaje>.bin (un .glb con otra extensión, para cargarlo tal cual).

Uso: python3 tools/pieces/aventura.py <carpeta con los .glb originales>   (Characters/gltf del pack)
"""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot/sets/aventura"
CHARACTERS = ["Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded"]
KEEP = [
    "Idle", "Walking_A", "Walking_C", "Running_A", "Jump_Full_Long", "Jump_Full_Short", "Cheer", "Hit_A", "Hit_B",
    "Death_A", "Death_A_Pose", "Death_B", "Death_B_Pose", "Block", "Interact",
    "1H_Melee_Attack_Stab", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Chop",
    "2H_Melee_Attack_Spin", "Dualwield_Melee_Attack_Slice", "Spellcast_Shoot", "Unarmed_Melee_Attack_Kick",
]


def strip(src: Path, dst: Path) -> None:
    data = src.read_bytes()
    jlen = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + jlen])
    bin_start = 20 + jlen + 8
    blob = data[bin_start:bin_start + struct.unpack("<I", data[20 + jlen:24 + jlen])[0]]

    gltf["animations"] = [a for a in gltf.get("animations", []) if a.get("name") in KEEP]
    missing = set(KEEP) - {a["name"] for a in gltf["animations"]}
    if missing:
        print("  faltan:", sorted(missing))
    used = set()
    for mesh in gltf.get("meshes", []):
        for prim in mesh["primitives"]:
            used.update(prim["attributes"].values())
            if "indices" in prim:
                used.add(prim["indices"])
            for target in prim.get("targets", []):
                used.update(target.values())
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            used.add(skin["inverseBindMatrices"])
    for anim in gltf["animations"]:
        for sampler in anim["samplers"]:
            used.update((sampler["input"], sampler["output"]))
    order = sorted(used)
    acc_map = {old: new for new, old in enumerate(order)}
    accessors = [gltf["accessors"][i] for i in order]

    views_used = sorted({a["bufferView"] for a in accessors if "bufferView" in a} | {i["bufferView"] for i in gltf.get("images", []) if "bufferView" in i})
    view_map = {old: new for new, old in enumerate(views_used)}
    out = bytearray()
    views = []
    for old in views_used:
        view = dict(gltf["bufferViews"][old])
        start = view.get("byteOffset", 0)
        while len(out) % 4:
            out.append(0)
        view["byteOffset"] = len(out)
        out += blob[start:start + view["byteLength"]]
        view["buffer"] = 0
        views.append(view)
    while len(out) % 4:
        out.append(0)

    for acc in accessors:
        if "bufferView" in acc:
            acc["bufferView"] = view_map[acc["bufferView"]]
    for image in gltf.get("images", []):
        if "bufferView" in image:
            image["bufferView"] = view_map[image["bufferView"]]
    for mesh in gltf.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = acc_map[prim["indices"]]
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
    for anim in gltf["animations"]:
        for sampler in anim["samplers"]:
            sampler["input"] = acc_map[sampler["input"]]
            sampler["output"] = acc_map[sampler["output"]]
    gltf["accessors"] = accessors
    gltf["bufferViews"] = views
    gltf["buffers"] = [{"byteLength": len(out)}]

    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(out)
    dst.write_bytes(b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(text)) + b"JSON" + text + struct.pack("<I", len(out)) + b"BIN\x00" + bytes(out))
    print(f"{src.name}: {len(data) // 1024} KB -> {total // 1024} KB, {len(gltf['animations'])} animaciones")


def main() -> None:
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for name in CHARACTERS:
        strip(src / f"{name}.glb", OUT / f"{name.lower()}.bin")


if __name__ == "__main__":
    main()
