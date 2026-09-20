#!/usr/bin/env python3
"""Keep the public feature catalogue aligned with feature metadata."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
START = "<!-- BEGIN GENERATED FEATURE CATALOGUE -->"
END = "<!-- END GENERATED FEATURE CATALOGUE -->"


def load_features() -> list[dict]:
    features = []
    for path in sorted((ROOT / "src").glob("*/devcontainer-feature.json")):
        feature = json.loads(path.read_text(encoding="utf-8"))
        feature["_path"] = path
        features.append(feature)
    return sorted(features, key=lambda feature: feature["id"])


def catalogue(features: list[dict], link_prefix: str) -> str:
    rows = [
        "| Feature | Status | Description |",
        "|---------|--------|-------------|",
    ]
    for feature in features:
        feature_id = feature["id"]
        status = "Deprecated" if feature.get("deprecated") else "Current"
        description = feature["description"].replace("|", "\\|")
        rows.append(
            f"| [`{feature_id}`]({link_prefix}{feature_id}.qmd) | {status} | {description} |"
        )
    return "\n".join(rows)


def replace_catalogue(path: Path, rendered: str) -> str:
    current = path.read_text(encoding="utf-8")
    block = f"{START}\n{rendered}\n{END}"
    pattern = re.compile(re.escape(START) + r".*?" + re.escape(END), re.DOTALL)
    if not pattern.search(current):
        raise ValueError(f"{path.relative_to(ROOT)} is missing generated catalogue markers")
    return pattern.sub(block, current, count=1)


def clean_cell(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`"):
        value = value[1:-1]
    return value.strip()


def normalise_default(value: str) -> str:
    value = clean_cell(value)
    if value in {"", "-"}:
        return ""
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    if value.lower() in {"true", "false"}:
        return value.lower()
    return value


def metadata_default(value: object) -> str:
    if isinstance(value, bool):
        return str(value).lower()
    if value is None:
        return "null"
    return str(value)


def parse_options_table(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^## Options\s*$\n(.*?)(?=^##\s|\Z)", text, re.MULTILINE | re.DOTALL)
    if not match:
        return {}

    table_lines = [line for line in match.group(1).splitlines() if line.strip().startswith("|")]
    if len(table_lines) < 2:
        return {}

    def cells(line: str) -> list[str]:
        return [clean_cell(cell) for cell in line.strip().strip("|").split("|")]

    header = [cell.lower() for cell in cells(table_lines[0])]
    try:
        option_index = next(i for i, cell in enumerate(header) if cell in {"option", "options id"})
        default_index = next(i for i, cell in enumerate(header) if cell in {"default", "default value"})
    except StopIteration:
        return {}

    options: dict[str, str] = {}
    for line in table_lines[2:]:
        row = cells(line)
        if len(row) <= max(option_index, default_index):
            continue
        option = row[option_index]
        if option:
            options[option] = normalise_default(row[default_index])
    return options


def validate_feature_pages(features: list[dict]) -> list[str]:
    errors = []
    docs_dir = ROOT / "docs" / "features"
    for feature in features:
        feature_id = feature["id"]
        page = docs_dir / f"{feature_id}.qmd"
        if not page.exists():
            errors.append(f"missing docs page: docs/features/{feature_id}.qmd")
            continue

        documented = parse_options_table(page)
        expected = {
            option: metadata_default(spec.get("default"))
            for option, spec in feature.get("options", {}).items()
        }
        if documented != expected:
            errors.append(
                f"option drift in docs/features/{feature_id}.qmd: "
                f"expected {expected}, found {documented}"
            )

        if feature.get("deprecated"):
            page_text = page.read_text(encoding="utf-8").lower()
            if "deprecated" not in page_text or "utils" not in page_text:
                errors.append(
                    f"deprecated feature docs must direct users to utils: docs/features/{feature_id}.qmd"
                )
    return errors


def validate_quarto_navigation(features: list[dict]) -> list[str]:
    errors = []
    path = ROOT / "docs" / "_quarto.yml"
    text = path.read_text(encoding="utf-8")
    expected_ids = {feature["id"] for feature in features}
    documented_ids = set(re.findall(r"features/([a-z0-9-]+)\.qmd", text))

    if documented_ids != expected_ids:
        errors.append(
            "docs/_quarto.yml feature navigation drift: "
            f"expected {sorted(expected_ids)}, found {sorted(documented_ids)}"
        )

    for feature in features:
        feature_id = feature["id"]
        count = text.count(f"features/{feature_id}.qmd")
        if count != 2:
            errors.append(
                f"docs/_quarto.yml should reference features/{feature_id}.qmd twice "
                f"(navbar and sidebar); found {count}"
            )
        if feature.get("deprecated") and f'text: "{feature_id} (deprecated)"' not in text:
            errors.append(f"docs/_quarto.yml must label {feature_id} as deprecated")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail instead of rewriting stale catalogues")
    args = parser.parse_args()

    features = load_features()
    generated = {
        ROOT / "README.md": catalogue(features, "docs/features/"),
        ROOT / "docs" / "index.qmd": catalogue(features, "features/"),
    }

    errors = []
    for path, rendered in generated.items():
        expected = replace_catalogue(path, rendered)
        current = path.read_text(encoding="utf-8")
        if current != expected:
            if args.check:
                errors.append(f"stale generated catalogue: {path.relative_to(ROOT)}")
            else:
                path.write_text(expected, encoding="utf-8")

    errors.extend(validate_quarto_navigation(features))
    errors.extend(validate_feature_pages(features))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        if args.check:
            print("Run: python3 scripts/docs_catalogue.py", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
