#!/bin/sh
# Creates the folder of a new release, from the newest release of its series.
# Called by `make new-release`, from the root of the repository.
#
# The first release of a series also gets a copy of the Dockerfile and _shared
# of the newest series. A stable release newer than version.txt becomes the
# latest; a prerelease never does.
set -eu

version="${1:?Usage: new-release.sh <version>}"

if ! echo "${version}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$'; then
    echo "Not a version: ${version}. Use 3.0.1 or 3.0.1-alpha.1" >&2
    exit 1
fi

core="${version%%-*}"
series="${core%.*}"

if [ -e "${series}/${version}" ]; then
    echo "${series}/${version} already exists" >&2
    exit 1
fi

# Sorts versions from stdin in semver order: a prerelease is older than its
# release, and sort -V puts `~` before the end of a version
semver_sort() {
    sed 's/-/~/' | sort -V | sed 's/~/-/'
}

newest_release_of() {
    for folder in "$1"/[0-9]*.*.*/; do
        basename "${folder}"
    done | semver_sort | tail -n 1
}

newest_series=$(
    for folder in [0-9]*.*/; do
        basename "${folder}"
    done | sort -V | tail -n 1
)

template="${series}"
if [ ! -d "${series}" ]; then
    template="${newest_series}"
    mkdir "${series}"
    cp -R "${template}/_shared" "${series}/_shared"
    sed "s#${template}/#${series}/#g" "${template}/Dockerfile" >"${series}/Dockerfile"
    grep -q "${series}/_shared/" "${series}/Dockerfile" || {
        echo "${series}/Dockerfile does not copy from ${series}/_shared" >&2
        exit 1
    }
    echo "Created ${series}/ from ${template}/"
fi

source="$(newest_release_of "${template}")"
mkdir "${series}/${version}"
cp "${template}/${source}/package.json" "${series}/${version}/package.json"
echo "Created ${series}/${version}/ from ${template}/${source}/"

case "${version}" in
    *-*) ;;
    *)
        newest=$(printf '%s\n%s\n' "$(cat version.txt)" "${version}" | semver_sort | tail -n 1)
        if [ "${newest}" = "${version}" ]; then
            echo "${version}" >version.txt
            echo "version.txt is now ${version}"
        fi
        ;;
esac
