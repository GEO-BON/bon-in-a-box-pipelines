#!/bin/bash
# Build, conda-pack and upload to S3 every conda environment used by BON in a Box
# scripts, plus the two shared base environments (rbase, pythonbase).
# Archives are tagged with the current pipeline-repo commit, and an unsuffixed
# "latest" copy is also kept so condaEnvironment.sh's CONDA_PACK_URL download
# path keeps working unmodified.
# An environment is skipped entirely (no create/pack/upload) if its spec is
# identical to what's already at s3://$S3_BUCKET/<envName>.yml.
#
# Env vars:
#   SCRIPTS_ROOT        Path to pipeline-repo/scripts (required)
#   CONDA_ENV_YML_DIR   Where extracted per-env yml specs are written (default: /conda-env-yml)
#   WORK_DIR            Scratch dir for packed archives before upload (default: /tmp/conda-pack-upload)
#   GIT_COMMIT          Commit hash to tag archives with (required)
#   S3_BUCKET           Target bucket (default: conda-pack)
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / S3_ENDPOINT_URL   Read directly by s5cmd

set -o pipefail

scriptDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

SCRIPTS_ROOT=${SCRIPTS_ROOT:?SCRIPTS_ROOT must be set}
GIT_COMMIT=${GIT_COMMIT:?GIT_COMMIT must be set}
CONDA_ENV_YML_DIR=${CONDA_ENV_YML_DIR:-/conda-env-yml}
WORK_DIR=${WORK_DIR:-/tmp/conda-pack-upload}
S3_BUCKET=${S3_BUCKET:-conda-pack}

failedEnvs=()
packedCount=0
skippedCount=0

function assertSuccess {
    if [[ $? -ne 0 ]] ; then
        echo -e "FAILED" ; exit 1
    fi
}

# Compares envYmlPath against the previously uploaded s3://$S3_BUCKET/<envName>.yml
# (if any). Mirrors the cmp-before-repacking idiom already used by
# condaPackEnvironment.sh and condaEnvironment.sh, just backed by S3 instead of
# a local file, since this script has no state across CI runs.
function unchangedSincePreviousUpload {
    envName=$1
    envYmlPath=$2

    prevYml="$WORK_DIR/$envName.prev.yml"
    rm -f "$prevYml"
    s5cmd cp "s3://$S3_BUCKET/tmp/$envName.yml" "$prevYml" > /dev/null 2>&1

    unchanged=1
    if [[ -f "$prevYml" ]] && cmp -s "$prevYml" "$envYmlPath"; then
        unchanged=0
    fi
    rm -f "$prevYml"
    return $unchanged
}

# Writes $CONDA_ENV_YML_DIR/<envName>.yml for every scripts/**/*.yml that has a
# top-level `conda:` key. Prints one envName per line.
# See extractCondaEnvs.py for the envName derivation (matches ScriptStep.kt).
function extractPerScriptEnvs {
    python3 "$scriptDir/extractCondaEnvs.py" "$SCRIPTS_ROOT" "$CONDA_ENV_YML_DIR"
}

# Packs one env to $WORK_DIR/<envName>.tar.gz, uploads commit-tagged + latest
# copies to S3 alongside its yml, then cleans up.
function packAndUpload {
    envName=$1
    envYmlPath=$2

    if unchangedSincePreviousUpload "$envName" "$envYmlPath"; then
        echo "Skipping $envName, unchanged since last upload."
        skippedCount=$((skippedCount + 1))
        return
    fi

    if ! mamba env list | grep -q " $envName "; then
        echo "Creating conda environment $envName..."
        mamba env create -y -n "$envName" -f "$envYmlPath"
        if [[ $? -ne 0 ]] ; then
            echo "    FAILED to create $envName."
            failedEnvs+=("$envName")
            return
        fi
    fi

    echo "Packing conda environment $envName..."
    mamba activate base ; assertSuccess
    tar="$WORK_DIR/$envName.tar"
    conda-pack --n-threads -1 --quiet -n "$envName" -o "$tar" --compress-level 0
    if [[ $? -ne 0 ]] ; then
        echo "    FAILED to pack $envName."
        failedEnvs+=("$envName")
        mamba deactivate # base
        return
    fi
    pigz "$tar" ; assertSuccess
    mamba deactivate # base

    zip="$tar.gz"
    yml="$WORK_DIR/$envName.yml"
    cp "$envYmlPath" "$yml" ; assertSuccess

    echo "Uploading $envName (commit $GIT_COMMIT)..."
    taggedZip="s3://$S3_BUCKET/tmp/$envName-$GIT_COMMIT.tar.gz"
    taggedYml="s3://$S3_BUCKET/tmp/$envName-$GIT_COMMIT.yml"
    s5cmd cp "$zip" "$taggedZip" ; assertSuccess
    s5cmd cp "$yml" "$taggedYml" ; assertSuccess

    # Refresh the unsuffixed "latest" pointer via a server-side copy, so
    # condaEnvironment.sh's CONDA_PACK_URL download path (which has no
    # knowledge of the commit hash) keeps finding the current archive.
    s5cmd cp "$taggedZip" "s3://$S3_BUCKET/tmp/$envName.tar.gz" ; assertSuccess
    s5cmd cp "$taggedYml" "s3://$S3_BUCKET/tmp/$envName.yml" ; assertSuccess

    rm -f "$zip" "$yml"
    packedCount=$((packedCount + 1))

    # Keep the base envs around, they are reused for every script without its own conda: section.
    if [[ "$envName" != "rbase" && "$envName" != "pythonbase" ]]; then
        mamba env remove -qy -n "$envName" > /dev/null 2>&1
    fi
}

source /.bashrc
mkdir -p "$CONDA_ENV_YML_DIR" "$WORK_DIR"

echo "Packing base environments..."
packAndUpload rbase /data/r-environment.yml
packAndUpload pythonbase /data/python-environment.yml

echo "Packing per-script environments..."
while IFS= read -r envName; do
    packAndUpload "$envName" "$CONDA_ENV_YML_DIR/$envName.yml"
done < <(extractPerScriptEnvs)

echo "Packed and uploaded $packedCount environment(s), skipped $skippedCount unchanged."
if [[ ${#failedEnvs[@]} -gt 0 ]]; then
    echo "FAILED environments: ${failedEnvs[*]}"
    exit 1
fi
