# Nick with PostgreSQL

Nick split in its three modules: a `migrate` container that migrates the
database and installs the profiles before the others start, the API on
http://localhost:8080, and a job worker. They share the blob storage volume.

```shell
docker compose up
```

Without `PROFILES`, Nick installs the demo site with an `admin` user whose
password is `admin`.
