#!/bin/sh
# Prints the releases a change affects, one per line. Run it from the root of
# the repository, with <head> checked out.
#
#   <series>/_shared/, <series>/Dockerfile  -> every stable release of the series
#   <series>/<version>/                     -> that release alone
#   version.txt                             -> the release it names, for `latest`
#
# Prereleases are frozen: they only build when their own folder changes.
#
# With --tooling, a change to what builds and tests the images (the workflows,
# scripts/, the Makefile) also affects the release in version.txt. Pull requests
# use this to try the change out; on main it publishes nothing.
#
# A <base> that does not exist, like the empty one of a first push, affects
# every stable release.
set -eu

tooling=false
if [ "${1:-}" = "--tooling" ]; then
    tooling=true
    shift
fi
base="${1:?Usage: changed-releases.sh [--tooling] <base> <head>}"
head="${2:?Usage: changed-releases.sh [--tooling] <base> <head>}"

# Prints the stable releases of the series given as arguments
stable_releases_of() {
    for series in "$@"; do
        for folder in "${series}"/[0-9]*.*.*/; do
            case "${folder}" in
                *-*) ;;
                *)
                    if [ -d "${folder}" ]; then
                        basename "${folder}"
                    fi
                    ;;
            esac
        done
    done
}

if ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
    stable_releases_of [0-9]*.*
    exit 0
fi

git diff --name-only --no-renames "${base}...${head}" | while IFS= read -r path; do
    case "${path}" in
        version.txt)
            cat version.txt
            ;;
        [0-9]*/_shared/* | [0-9]*/Dockerfile)
            stable_releases_of "${path%%/*}"
            ;;
        [0-9]*/[0-9]*/*)
            series="${path%%/*}"
            rest="${path#*/}"
            version="${rest%%/*}"
            # The folder of a release removed by this change has nothing to build
            if [ -d "${series}/${version}" ]; then
                echo "${version}"
            fi
            ;;
        .github/workflows/* | scripts/* | Makefile)
            if [ "${tooling}" = "true" ]; then
                cat version.txt
            fi
            ;;
    esac
done | sort -uV
