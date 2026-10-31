<p align="center">
  <img alt="Plone Logo" width="200" src="https://raw.githubusercontent.com/plone/plone-frontend/15.x/docs/logo.png">
</p>

<h1 align="center">plone/nick</h1>

<div align="center">

[![Docker Image Version](https://img.shields.io/docker/v/plone/nick?sort=semver)](https://hub.docker.com/r/plone/nick)
[![Docker Image Size](https://img.shields.io/docker/image-size/plone/nick?sort=semver)](https://hub.docker.com/r/plone/nick)
[![GitHub stars](https://img.shields.io/github/stars/plone/container-nick?style=flat-square)](https://github.com/plone/container-nick)
[![License](https://img.shields.io/github/license/plone/container-nick)](./LICENSE.md)

</div>

Official container image for [Nick](https://nick.docs.plone.org), the Nearly
Headless CMS that serves the Plone REST API. This repository contains only the
image build and release machinery; Nick development happens in
[`plone/nick`](https://github.com/plone/nick).

The image is a Nick project in `/app` that depends on `@plone/nick` from npm.
Nick runs from its TypeScript sources with the `tsx` loader, which the image
warms up at build time.

## Images

For each Nick release, the release workflow publishes `plone/nick:<version>` for
`linux/amd64` and `linux/arm64`. The moving tags go to the newest release they
cover: `3.0` to the newest `3.0.x`, `3` to the newest `3.x`, and `latest` to
the version in [`version.txt`](./version.txt). A prerelease, like
`3.1.0-alpha.1`, only gets its own tag.

## Repository layout

```
version.txt             the latest release
scripts/                repository tooling, not part of any image
3.0/
  Dockerfile            how the 3.0 series is built
  _shared/              what the 3.0 images share: entrypoint, workspace, tsconfig
  3.0.0/
    package.json        pins pnpm and the supported Node versions
    pnpm-lock.yaml      pins every dependency of this release
```

A release folder pins the complete dependency tree. When a dependency has a
security issue, update the lockfile of each affected release, and the images of
those releases rebuild with the fix and nothing else. A series has its own
`_shared`, so a breaking change there stays in that series.

There are no git tags: merging to `main` publishes the images a change affects.

| Change                                  | Images published         |
| --------------------------------------- | ------------------------ |
| `3.0/3.0.1/` added or changed           | 3.0.1 only               |
| `3.0/_shared/` or `3.0/Dockerfile`      | every stable 3.0 release |
| `version.txt`                           | the version it names     |
| Anything else                           | none                     |

Prereleases are frozen: they only build when their own folder changes, so a fix
in `_shared` does not reach them. Remove their folders when the final release
ships: their images stay published, and removing a folder builds nothing.

Published images are rebuilt in place: `plone/nick:3.0.0` moves when its release
changes. Use the image digest to pin one build.

## Usage

Nick needs a PostgreSQL database. The image runs `nick`, which migrates the
database, installs the profiles, and starts the API (on port 8080) and the job
worker:

```shell
docker run --rm -p 8080:8080 \
  -e DB_HOST=db -e DB_PASSWORD=nick -e SECRET=change-me \
  plone/nick:latest
```

[`examples/nick-postgres`](./examples/nick-postgres) runs it with PostgreSQL
using Docker Compose.

Pass the modules to run as the command, or set `NICK_MODULES`, to split them
across containers:

```shell
docker run plone/nick --modules=migrate       # migrate and exit (non-zero on errors)
docker run plone/nick --modules=api           # API only
docker run plone/nick --modules=worker        # job worker and scheduler
```

See [Deployment](https://nick.docs.plone.org/admin-guide/deployment) in the
Nick documentation.

### Configuration

| Variable          | Description                                                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection. `DB_PASSWORD` is required.                                                                                 |
| `SECRET`          | Secret to sign the authentication tokens. Required.                                                                                                           |
| `PROFILES`        | Profiles to install, comma separated. Default: `@plone/nick:default`, the demo site with an `admin` user whose password is `admin`.                           |
| `NICK_MODULES`    | Modules to run: `migrate`, `api`, `worker`, comma separated. Default: all of them.                                                                            |
| `PORT`            | Port of the API. Default: `8080`.                                                                                                                             |
| `ALLOWED_ORIGINS` | Origins allowed by CORS, like the URL of the frontend.                                                                                                        |
| `BLOBS_DIR`       | Directory of the `file` blob storage. Default: `/app/var/blobstorage`; mount a volume there, or use the `db` or `s3` blob storage.                            |
| `ADDONS`          | Add-ons from npm to install when the container starts, space separated `pnpm add` specs. For trying them out: build an image with the add-ons for production. |

Nick reads the rest of its settings from the environment as well; see the
Nick documentation. A `config.ts` mounted at `/app/config.ts` replaces the
environment configuration.

## Add-ons

A Nick add-on is an npm package with profiles, migrations and code (see
[Add-ons](https://nick.docs.plone.org/developer-guide/addons)). Build an image
of your own on this one to add them.

### Add-ons of your project

Projects generated with [Cookieplone](https://github.com/plone/cookieplone)
(`volto_nick`, `aurora_nick`) keep their Nick add-on in
`backend/packages/<add-on>`, and their `backend/Dockerfile` builds on this
image. Copy the add-ons into `/app/packages`, where they are workspace
packages of the image's project, and add them:

```dockerfile
FROM plone/nick:3.0.0

COPY --chown=node:node packages /app/packages
RUN pnpm add "nick-my-project@workspace:*"

ENV PROFILES=@plone/nick:core,nick-my-project:default
```

Every `@plone/nick` in the image, like the peer dependency of an add-on, is the
image's own Nick: an add-on with a Nick of its own would register its code in a
registry the running Nick never reads. Add-ons can depend on `@plone/nick`
with `workspace:^` for development in their project, as Nick's
`nick-example-addon` does.

### Add-ons from npm

```dockerfile
FROM plone/nick:3.0.0

RUN pnpm add @acme/nick-addon@1.2.0

ENV PROFILES=@plone/nick:core,@acme/nick-addon:default
```

Building this repository's image works too:

```shell
make build-image ADDONS="@acme/nick-addon@1.2.0"
```

To try an add-on out without building an image, set `ADDONS`; the container
installs it on every start:

```shell
docker run -e ADDONS="@acme/nick-addon" \
  -e PROFILES=@plone/nick:core,@acme/nick-addon:default ... plone/nick
```

## Development

Build the image of the release in `version.txt`, or of any other release folder:

```shell
make build-image
make build-image VERSION=3.0.0
```

Build an unreleased Nick, from a tarball or any other `pnpm add` spec. The image
has no git, so `github:` specs do not work:

```shell
make build-image NICK_SPEC=https://codeload.github.com/plone/nick/tar.gz/main
```

To add a release, create it and open a pull request. Merging it publishes the
image:

```shell
make new-release VERSION=3.0.1
make new-release VERSION=3.1.0-alpha.1
```

This copies the `package.json` of the newest release of the series and resolves
the lockfile, so the version must already be on npm; if it is not yet, run
`make lock VERSION=3.0.1` once it is. The first release of a series also copies
the `Dockerfile` and `_shared` of the newest series. A stable release newer than
`version.txt` updates it; a prerelease never does.

To fix a dependency of a published release, update the release's lockfile and
merge it. `make lock` resolves the whole tree again, so review the diff of the
lockfile.

If a publish fails, the next merge does not pick it up. Run the release workflow
by hand with the version.

`make lint` lints the Dockerfiles, the scripts and the workflows. Use `make help`
for the other targets.

## Contributing

- [Issue tracker](https://github.com/plone/container-nick/issues)
- [Source code](https://github.com/plone/container-nick)

Do not commit directly to `main`: merging there publishes images. Open a pull
request and have another maintainer merge it.

## License

This project is licensed under the MIT license.
