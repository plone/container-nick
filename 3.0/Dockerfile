# syntax=docker/dockerfile:1
#
# Production image of Nick, as a Nick project in /app that depends on
# @plone/nick: the layout of a project created with the Nick generator.
#
#   docker run plone/nick                         # migrate, then api + worker
#   docker run plone/nick --modules=migrate       # migrate and exit (non-zero on errors)
#   docker run plone/nick --modules=api           # API on $PORT (default 8080)
#   docker run plone/nick --modules=worker        # job worker and scheduler
#
# Configuration comes from environment variables (DB_HOST, DB_PASSWORD,
# SECRET, PROFILES, ...) or from a config.ts mounted at /app/config.ts.

ARG NODE_VERSION=26.2.0
FROM node:${NODE_VERSION}-bookworm-slim

# The Nick release: a folder next to this Dockerfile. The build context is the
# root of the repository.
ARG NICK_VERSION
# What to install as @plone/nick: the release from npm by default, or any
# other pnpm spec without git, which the image does not have, like
# https://codeload.github.com/plone/nick/tar.gz/<commit> to try out a commit
ARG NICK_SPEC=${NICK_VERSION}
# Add-ons to build in, space separated `pnpm add` specs like
# "@acme/nick-addon@1.2.0". Select their profiles with PROFILES.
ARG ADDONS=""

LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="nick" \
      org.label-schema.description="Nick, the Nearly Headless CMS" \
      org.label-schema.vendor="Plone Foundation"

ENV NODE_ENV=production \
    PORT=8080 \
    BLOBS_DIR=/app/var/blobstorage \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0

RUN <<EOT
    set -e
    npm install -g corepack@latest
    corepack enable
    mkdir -p /app/var/blobstorage
    chown -R node:node /app
EOT

USER node
WORKDIR /app

COPY --chown=node:node 3.0/_shared/pnpm-workspace.yaml 3.0/_shared/tsconfig.json 3.0/_shared/docker-entrypoint.sh ./
COPY --chown=node:node 3.0/${NICK_VERSION}/package.json 3.0/${NICK_VERSION}/pnpm-lock.yam[l] ./
COPY --chown=node:node 3.0/_shared/pin-nick.sh /tmp/pin-nick.sh

# The pnpm store stays in the image, in the same layer as node_modules (so it
# costs only hard links): images built FROM this one, and ADDONS at start, then
# add packages without downloading Nick's dependencies again.
RUN <<EOT
    set -e
    test -n "${NICK_SPEC}" || { echo "NICK_VERSION is not set" >&2; exit 1; }
    sh /tmp/pin-nick.sh "${NICK_SPEC}"
    corepack install
    if [ "${NICK_SPEC}" = "${NICK_VERSION}" ]; then
      # A release installs exactly what its lockfile pins, and fails without one
      pnpm install --frozen-lockfile
    else
      rm -f pnpm-lock.yaml
      pnpm install --no-frozen-lockfile
    fi
    if [ -n "${ADDONS}" ]; then
      # shellcheck disable=SC2086  # ADDONS is a space separated list
      pnpm add ${ADDONS}
    fi
EOT

# Compile the sources once at build time, so the TypeScript loader (tsx)
# starts from a warm cache
RUN NODE_ENV=development node --import tsx -e "await import('@plone/nick/src/helpers/modules/modules.ts'); await import('@plone/nick/src/app.ts'); process.exit(0)"

EXPOSE 8080

# Healthy when @health passes; processes without the api module have no HTTP
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=3 \
  CMD ["node", "-e", "const m=process.env.NICK_MODULES||'all'; if(m!=='all'&&!m.split(',').includes('api'))process.exit(0); fetch('http://127.0.0.1:'+process.env.PORT+'/@health',{headers:{Accept:'application/json'}}).then(r=>r.json()).then(j=>process.exit(j.status==='fail'?1:0)).catch(()=>process.exit(1))"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD []
