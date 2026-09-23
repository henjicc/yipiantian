"""Point identical embedded GLB images at one external runtime texture.

The editable originals stay in ArtSource. Run this after exporting game GLBs;
Godot then imports one image resource for each shared image instead of extracting
another copy for every model. No image is recompressed or rescaled here.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
from urllib.parse import quote, unquote


MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}


def read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) < 28 or raw[:4] != MAGIC or struct.unpack_from("<II", raw, 4) != (2, len(raw)):
        raise ValueError(f"Invalid GLB: {path}")
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    bin_header = 20 + json_length
    if json_type != JSON_CHUNK or bin_header + 8 > len(raw):
        raise ValueError(f"Unexpected GLB chunks: {path}")
    bin_length, bin_type = struct.unpack_from("<II", raw, bin_header)
    if bin_type != BIN_CHUNK or bin_header + 8 + bin_length != len(raw):
        raise ValueError(f"Expected one JSON and one BIN chunk: {path}")
    document = json.loads(raw[20:bin_header])
    binary = raw[bin_header + 8 :]
    buffers = document.get("buffers", [])
    if len(buffers) != 1 or buffers[0].get("uri") or buffers[0]["byteLength"] > len(binary):
        raise ValueError(f"Expected one embedded binary buffer: {path}")
    return document, binary


def image_bytes(document: dict, binary: bytes, image: dict) -> bytes:
    view = document["bufferViews"][image["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise ValueError("Image uses an external binary buffer")
    start = view.get("byteOffset", 0)
    end = start + view["byteLength"]
    if end > len(binary):
        raise ValueError("Image buffer view exceeds the GLB")
    return binary[start:end]


def other_buffer_view_references(value: object, found: set[int]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "images":
                continue
            if key == "bufferView" and isinstance(child, int):
                found.add(child)
            else:
                other_buffer_view_references(child, found)
    elif isinstance(value, list):
        for child in value:
            other_buffer_view_references(child, found)


def encode_glb(document: dict, original_binary: bytes, discard_views: set[int]) -> bytes:
    binary = bytearray(b"\0")  # Valid one-byte placeholder for now-unused views.
    for index, view in enumerate(document["bufferViews"]):
        if view.get("buffer", 0) != 0:
            raise ValueError("External binary buffer view is unsupported")
        if index in discard_views:
            view["byteOffset"] = 0
            view["byteLength"] = 1
            continue
        binary.extend(b"\0" * (-len(binary) % 4))
        start = view.get("byteOffset", 0)
        end = start + view["byteLength"]
        if end > len(original_binary):
            raise ValueError("Buffer view exceeds the original GLB")
        view["byteOffset"] = len(binary)
        binary.extend(original_binary[start:end])
    document["buffers"][0]["byteLength"] = len(binary)
    json_bytes = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    result = bytearray(struct.pack("<4sII", MAGIC, 2, 12 + 8 + len(json_bytes) + 8 + len(binary)))
    result.extend(struct.pack("<II", len(json_bytes), JSON_CHUNK))
    result.extend(json_bytes)
    result.extend(struct.pack("<II", len(binary), BIN_CHUNK))
    result.extend(binary)
    return bytes(result)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def choose_image(paths: list[Path]) -> Path:
    return min(paths, key=lambda path: ("_high_" not in path.stem.lower(), len(path.parts), path.as_posix()))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art", type=Path, required=True, help="Game/art directory")
    parser.add_argument("--all", action="store_true", help="Scan every GLB below Game/art")
    parser.add_argument("models", nargs="*", type=Path, help="Selected GLBs for a small trial")
    args = parser.parse_args()
    art = args.art.resolve(strict=True)
    models = sorted(art.rglob("*.glb")) if args.all else sorted(path.resolve(strict=True) for path in args.models)
    if not models or (args.all and args.models):
        parser.error("Provide --all or at least one model, not both")
    if any(not path.is_relative_to(art) or path.suffix.lower() != ".glb" for path in models):
        parser.error("Models must be GLBs below Game/art")

    contents: dict[Path, tuple[dict, bytes]] = {}
    groups: dict[tuple[str, str], list[tuple[Path, int, bytes]]] = {}
    for path in models:
        document, binary = read_glb(path)
        contents[path] = (document, binary)
        for index, image in enumerate(document.get("images", [])):
            if "bufferView" in image:
                data = image_bytes(document, binary, image)
                mime = image.get("mimeType", "")
            elif "uri" in image and not image["uri"].startswith("data:"):
                source = (path.parent / unquote(image["uri"])).resolve(strict=True)
                if not source.is_relative_to(art) or source.suffix.lower() not in IMAGE_SUFFIXES:
                    raise ValueError(f"External image outside Game/art: {source}")
                data = source.read_bytes()
                mime = "image/png" if source.suffix.lower() == ".png" else "image/jpeg"
            else:
                continue
            key = (sha256(data), mime)
            groups.setdefault(key, []).append((path, index, data))
    shared = {key: images for key, images in groups.items() if len(images) > 1}
    wanted_sizes = {len(images[0][2]) for images in shared.values()}
    candidates: dict[tuple[str, str], list[Path]] = {}
    for path in art.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES or path.stat().st_size not in wanted_sizes:
            continue
        mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
        key = (sha256(path.read_bytes()), mime)
        if key in shared:
            candidates.setdefault(key, []).append(path)

    assignments: dict[tuple[Path, int], Path] = {}
    group_report = []
    for key, images in sorted(shared.items()):
        choices = candidates.get(key, [])
        if choices:
            target = choose_image(choices)
        else:
            first_model, _, data = images[0]
            suffix = ".png" if key[1] == "image/png" else ".jpg"
            target = first_model.with_name(f"{first_model.stem}_shared_{key[0][:12]}{suffix}")
            if target.exists() and sha256(target.read_bytes()) != key[0]:
                raise ValueError(f"Existing target has different content: {target}")
            target.write_bytes(data)
        for model, index, _ in images:
            assignments[(model, index)] = target
        group_report.append({"sha256": key[0], "models": len({model for model, _, _ in images}), "references": len(images), "canonical": target.relative_to(art).as_posix(), "matching_sources": [path.relative_to(art).as_posix() for path in choices]})

    changed = []
    for path, (document, original_binary) in contents.items():
        linked_views = set()
        linked_images = 0
        for index, image in enumerate(document.get("images", [])):
            target = assignments.get((path, index))
            if target is None:
                continue
            uri = quote(Path(os.path.relpath(target, path.parent)).as_posix(), safe="/-._~")
            if image.get("uri") == uri:
                continue
            if "bufferView" in image:
                linked_views.add(image.pop("bufferView"))
            image.pop("mimeType", None)
            image["uri"] = uri
            linked_images += 1
        if not linked_images:
            continue
        used_elsewhere: set[int] = set()
        other_buffer_view_references(document, used_elsewhere)
        for image in document.get("images", []):
            if "bufferView" in image:
                used_elsewhere.add(image["bufferView"])
        discard_views = linked_views - used_elsewhere
        original_glb_size = path.stat().st_size
        packed = encode_glb(document, original_binary, discard_views)
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + ".", suffix=".tmp", delete=False) as temporary:
            temporary.write(packed)
            temporary_path = Path(temporary.name)
        try:
            verified, _ = read_glb(temporary_path)
            if len(verified.get("images", [])) != len(document.get("images", [])):
                raise ValueError(f"Image count changed: {path}")
            os.replace(temporary_path, path)
        finally:
            temporary_path.unlink(missing_ok=True)
        changed.append({"model": path.relative_to(art).as_posix(), "before_glb_bytes": original_glb_size, "after_glb_bytes": len(packed), "linked_images": linked_images})
    print(json.dumps({"shared_groups": group_report, "changed_models": changed}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
