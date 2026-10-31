#!/bin/sh
# Prints, as key=value lines, what the release of a version publishes. Run it
# from the root of the repository.
#
# version.txt alone decides `latest`. A rebuild of an older release, for a fix
# in a dependency, keeps the moving tags of the newer ones: 3.0.1 only gets `3.0`
# if it is the newest 3.0 folder, and `3` if it is the newest 3.x folder. A
# prerelease only ever gets its own tag.
set -eu

version="${1:?Usage: release-info.sh <version>}"
core="${version%%-*}"
series="${core%.*}"
major="${version%%.*}"

test -f "${series}/${version}/package.json" || {
    echo "No ${series}/${version}/package.json" >&2
    exit 1
}

# Prints the newest stable release of the folders given as arguments
newest_stable() {
    for folder in "$@"; do
        basename "${folder}"
    done | grep -v -e - | sort -V | tail -n 1
}

is() {
    if [ "$1" = "$2" ]; then echo true; else echo false; fi
}

echo "series=${series}"
echo "is-latest=$(is "${version}" "$(cat version.txt)")"
echo "is-newest-of-series=$(is "${version}" "$(newest_stable "${series}"/*.*.*/)")"
echo "is-newest-of-major=$(is "${version}" "$(newest_stable "${major}".*/*.*.*/)")"
