#!/bin/sh
set -e

# ADDONS installs add-ons when the container starts, for trying them out. Every
# start installs them again, from the network; for production, build an image
# with the add-ons instead (see the README).
if [ -n "${ADDONS}" ]; then
  echo "Installing add-ons: ${ADDONS}"
  echo "Build an image with the add-ons for production, see https://github.com/plone/container-nick"
  # shellcheck disable=SC2086  # ADDONS is a space separated list
  pnpm add ${ADDONS}
fi

exec node --import tsx node_modules/@plone/nick/scripts/nick.ts "$@"
