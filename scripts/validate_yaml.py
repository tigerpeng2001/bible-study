#!/usr/bin/env python3
"""Validate YAML files by parsing them with PyYAML."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

try:
    import yaml
except ModuleNotFoundError:
    sys.stderr.write(
        "PyYAML is required for YAML validation. Install it with "
        "`python3 -m pip install pyyaml`.\n"
    )
    sys.exit(2)


def validate_file(path: Path) -> str | None:
    """Return an error message for an invalid file, otherwise None."""
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return f"{path}: file not found."
    except OSError as exc:  # pragma: no cover - defensive path
        return f"{path}: unable to read file ({exc})."

    try:
        # Parse every document to surface errors early.
        list(yaml.safe_load_all(text))
    except yaml.YAMLError as exc:
        return f"{path}: YAML parse error: {exc}"

    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate YAML files.")
    parser.add_argument("files", nargs="+", help="Paths to YAML files to validate.")
    args = parser.parse_args()

    errors: list[str] = []
    for raw_path in args.files:
        path = Path(raw_path)
        error = validate_file(path)
        if error:
            errors.append(error)

    if errors:
        sys.stderr.write("\n".join(errors) + "\n")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
