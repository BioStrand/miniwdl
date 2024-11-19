#!/bin/bash
set -euo pipefail

get_quetz_general_api_key() {
    QUETZ_SECRET_ID="arn:aws:secretsmanager:eu-west-1:955241202820:secret:quetz-dvSVu2"
    QUETZ_GENERAL_API_KEY=$(aws secretsmanager get-secret-value --secret-id "$QUETZ_SECRET_ID" | jq -r '.SecretString | fromjson | .quetz_general_api_key')
    echo "$QUETZ_GENERAL_API_KEY"
}

generate_condarc() {
    local file="$1"
    touch "$file"
    cat <<EOF > "$file"
conda_build:
  pkg_format: 2
channel_priority: strict
unsatisfiable_hints: True
solver: libmamba
EOF
}

CONDA="${CONDA_BIN:-conda}"
if [ -n "${CONDA_KEY-}" ]; then
    export CONDA_KEY="$CONDA_KEY"
else
    export CONDA_KEY=$(get_quetz_general_api_key)
fi


conda-env-init() {
    if ! "$CONDA" env list | grep -q "$(pwd)"; then
        "$CONDA" create --strict-channel-priority -y -p ./.conda-env -c conda-forge python=3.10
    fi
}

conda-env-rc() {
    conda-env-init || true && \
    mkdir -p ./.conda-env  && \
    generate_condarc "./.conda-env/.condarc"
}

conda-env-create() {
    set -x
    "$CONDA" env create -p ./.conda-env --file environment.yml && \
    ./.conda-env/bin/pip install --no-deps .
    set +x
}

conda-env-dev-create() {
    set -x
    "$CONDA" env create -p ./.conda-env --file environment.dev.yml && \
    ./.conda-env/bin/pip install --no-deps -e .
    set +x
}

conda-env() {
    conda-env-rc
    conda-update
}


conda-env-dev() {
    conda-env-rc
    conda-update-dev
}

conda-update() {
    set -x
    if [ "$CONDA" == "conda" ]; then
        conda env update -p ./.conda-env --file environment.yml
    elif [ "$CONDA" == "mamba" ]; then
        mamba update -p ./.conda-env --file environment.yml
    elif [ "$CONDA" == "micromamba" ]; then
        # micromamba update often doesn't work as intended
        micromamba install -p ./.conda-env --file environment.yml \
        --rc-file ./.conda-env/.condarc
    else
        echo "Unknown conda binary: $CONDA"
        exit 1
    fi
    # When using conda-pack, the locally installed package and entry point scripts
    # won't be included in the tarball unless it is copied into the right directory
    ./.conda-env/bin/pip install --no-deps \
    --target ./.conda-env/lib/python3.10/site-packages . && \
    cp -r biostrand/ \
    .conda-env/lib/python3.10/site-packages/ && \
    mkdir -p ./.conda-env/lib/python3.10/site-packages/bin && \
    find ./.conda-env/lib/python3.10/site-packages/bin/ \
    -type f -exec cp {} ./.conda-env/bin/ \;
    set +x
}

conda-update-dev() {
    set -x
    if [ "$CONDA" == "conda" ]; then
        conda env update -p ./.conda-env --file environment.dev.yml
    elif [ "$CONDA" == "mamba" ]; then
        mamba env update -p ./.conda-env --file environment.dev.yml
    elif [ "$CONDA" == "micromamba" ]; then
    # micromamba update often doesn't work as intended
        micromamba install -p ./.conda-env --file environment.dev.yml \
        --rc-file ./.conda-env/.condarc
    else
        echo "Unknown conda binary: $CONDA"
        exit 1
    fi
    ./.conda-env/bin/pip install --no-deps -e .
    set +x
}


conda-activate() {
    echo "You have to do this manually by running: conda activate ./.conda-env"
}

conda-add-req() {
    update_environment_file environment.yml "$@"
    update_environment_file environment.dev.yml "$@"
    echo "Make sure you add the new dependencies to the conda recipe: $*"
}

update_environment_file() {
	a="$(echo "${@:2}" | awk '{for (i = 1; i <=NF; i++) printf "%s, ",$i}')";
    echo "[${a%??}]" | \
	yq '. | to_entries | map(.value)' | \
	yq eval-all ' select(fi == 0).dependencies as $init_dependencies | ($init_dependencies | . | length ) as $init_len | ($init_dependencies [] | has ("pip") | select (. == true) | key // $init_len) as $pos | $init_dependencies.[:$pos] + select(fi == 1) + $init_dependencies.[$pos:] as $updated_dependencies | select(fi == 0).dependencies = $updated_dependencies | select(has("dependencies")) ' "$1" - > "$1.tmp"
    mv "$1.tmp" "$1"
}

micromamba_sub_token() {
    sed 's/${CONDA_KEY}/'"$CONDA_KEY"'/g' "$1" > /tmp/tmp_sed; cat /tmp/tmp_sed > "$1"; rm /tmp/tmp_sed
}

micromamba_reset_token() {
    sed 's|/t/.*/get|/t/${CONDA_KEY}/get|g' "$1" > /tmp/tmp_sed; cat /tmp/tmp_sed > "$1"; rm /tmp/tmp_sed
}

docker() {
    CONDA_KEY=$(get_quetz_general_api_key)
    export DOCKER_BUILDKIT=1
    set -x
    command docker build --ulimit nofile=65536:65536 --build-arg CONDA_KEY="$CONDA_KEY" -t miniwdl .
    set +x
}

test() {
    pytest tests/
}

# Main script starts here
error_string="Usage: $0 {conda-env-rc|conda-env-init|conda-env-create|conda-env-dev-create|conda-env|conda-env-dev|conda-update|conda-update-dev|conda-activate|conda-add-req|micromamba_sub_token|micromamba_reset_token|docker|test}"
if [ "$#" -eq 0 ]; then
    echo "$error_string"
    exit 1
fi
case "$1" in
    "conda-env-rc") conda-env-rc;;
    "conda-env-init") conda-env-init;;
    "conda-env-create") conda-env-create;;
    "conda-env-dev-create") conda-env-dev-create;;
    "conda-env") conda-env;;
    "conda-env-dev") conda-env-dev;;
    "conda-update") conda-update;;
    "conda-update-dev") conda-update-dev;;
    "conda-activate") conda-activate;;
    "conda-add-req") conda-add-req "${@:2}";;
    "get_quetz_general_api_key") get_quetz_general_api_key;;
    "micromamba_sub_token") micromamba_sub_token "$2";;
    "micromamba_reset_token") micromamba_reset_token "$2";;
    "docker") docker;;
    "test") test;;
    *) echo "$error_string"; exit 1;;
esac