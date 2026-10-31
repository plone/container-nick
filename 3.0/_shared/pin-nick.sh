#!/bin/sh
# Pins @plone/nick in the pnpm-workspace.yaml of the current directory.
#
# @plone/nick comes from the catalog, and every @plone/nick in the tree, like
# the peer dependency of an add-on, is overridden with it: an add-on with a
# Nick of its own would register its code in a registry the running Nick never
# reads.
#
# The image build and scripts/update-lock.sh both run this, because the lockfile
# only matches a workspace file with the same catalog.
set -eu

spec="${1:?Usage: pin-nick.sh <pnpm spec of @plone/nick>}"

printf "\ncatalog:\n  '@plone/nick': '%s'\n\noverrides:\n  '@plone/nick': 'catalog:'\n" "${spec}" >>pnpm-workspace.yaml
