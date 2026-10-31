#!/bin/sh
# Resolves the pnpm-lock.yaml of a release, in a throwaway directory. Called by
# `make lock`, in the Node image of the series, with the repository in /repo.
set -eu

version="${1:?Usage: update-lock.sh <version>}"
core="${version%%-*}"
series="${core%.*}"
release="/repo/${series}/${version}"

test -f "${release}/package.json" || {
    echo "No ${series}/${version}/package.json" >&2
    exit 1
}

npm install -g corepack@latest
corepack enable

workdir=$(mktemp -d)
cd "${workdir}"
cp "${release}/package.json" "/repo/${series}/_shared/pnpm-workspace.yaml" .
sh "/repo/${series}/_shared/pin-nick.sh" "${version}"
COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm install --lockfile-only
cp pnpm-lock.yaml "${release}/pnpm-lock.yaml"
echo "Updated ${series}/${version}/pnpm-lock.yaml"
