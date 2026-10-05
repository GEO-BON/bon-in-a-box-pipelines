#!/usr/bin/env python3
# Writes <condaEnvYmlDir>/<envName>.yml for every scripts/**/*.yml that has a
# top-level `conda:` key, using the same envName transform as ScriptStep.kt
# (relative path from scripts root, '/' -> '__', ' ' -> '_', strip .yml suffix).
# Prints one envName per line.
#
# Usage: extractCondaEnvs.py <scriptsRoot> <condaEnvYmlDir>

import pathlib
import sys

import yaml


def main(scriptsRootArg: str, condaEnvYmlDirArg: str) -> None:
    scriptsRoot = pathlib.Path(scriptsRootArg)
    condaEnvYmlDir = pathlib.Path(condaEnvYmlDirArg)
    condaEnvYmlDir.mkdir(parents=True, exist_ok=True)

    for ymlFile in sorted(scriptsRoot.rglob("*.yml")):
        doc = yaml.safe_load(ymlFile.read_text()) or {}
        condaSection = doc.get("conda")
        if not condaSection:
            continue

        envName = str(ymlFile.relative_to(scriptsRoot)).replace("/", "__").replace(" ", "_")
        envName = envName.removesuffix(".yml")
        condaSection["name"] = envName

        (condaEnvYmlDir / f"{envName}.yml").write_text(yaml.dump(condaSection))
        print(envName)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
