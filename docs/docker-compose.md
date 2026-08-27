# Docker Compose

The Docker Compose deployment runs the on-prem API as one
container containing the API, processing workers, and runtime models.

## Prerequisites

-   Docker 20.10.5 or newer
-   Docker Compose 2.22.0 or newer
-   A Linux AMD64 host
-   A [license](licensing.md)
-   The image version provided with the product release

## Compose file

The repository includes a runnable
[`docker-compose.yaml`](../deploy/docker-compose/docker-compose.yaml) and an
[`.env.example`](../deploy/docker-compose/.env.example).

Copy both files into the deployment directory, rename `.env.example` to `.env`,
and set the image version and license values. Keep `.env` out of version
control and restrict access to it because it contains the license key.

Set `BLINKID_VERIFY_IMAGE_TAG` to the image version listed in the product
release. Keep the image repository unchanged unless Microblink supplies a
different registry.

Keep the default `DOCVER_WORKFLOW=ExtractAndVerify` for document verification.
For document and barcode extraction without verification, set
`DOCVER_WORKFLOW=Extract` instead.
See [Deployment modes](deployment-modes.md) before changing the mode.
See [Environment variables](environment-variables.md) for all supported
runtime settings and image defaults.

The reference defaults reject excess requests immediately instead of building
an in-container backlog. Review
[Queueing and backpressure](scaling.md#queueing-and-backpressure) before
changing admission limits, and use
[Estimating capacity](scaling.md#estimating-capacity) to choose CPU and memory
limits.

## Start the deployment

```bash
docker compose --file docker-compose.yaml up -d
```

The API is available on port `8080` by default. Wait for it to become ready:

```bash
curl --fail http://localhost:8080/health/ready
```

With the default `ExtractAndVerify` workflow, send a verification request:

```bash
curl --fail --location --output sample-front.jpg \
  https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_FRONT_new/SGP_ID_FRONT_sample.jpg
curl --fail --location --output sample-back.jpg \
  https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_BACK_new/SGP_ID_BACK_sample.jpg

curl -X POST http://localhost:8080/api/v3/verify \
  -F "imageFirstSide=@sample-front.jpg" \
  -F "imageSecondSide=@sample-back.jpg"
```

With the `Extract` workflow, `/api/v3/verify` is disabled. Send an extraction
request instead:

```bash
curl -X POST http://localhost:8080/api/v3/extract \
  -F "imageFirstSide=@sample-front.jpg"
```

More examples are available in [API integration](api-integration.md).
Health and shutdown settings are described in the
[environment-variable reference](environment-variables.md#health-and-shutdown).

## Logs and status

```bash
docker compose --file docker-compose.yaml ps
docker compose --file docker-compose.yaml logs -f blinkid-verify
```

The container writes component logs to standard output and standard error.
Optional file logging is described in
[Environment variables](environment-variables.md#logging-and-metrics).

## Stop the deployment

```bash
docker compose --file docker-compose.yaml down
```

## Update the deployment

Change the image version to the intended release, then recreate the container:

```bash
docker compose --file docker-compose.yaml pull
docker compose --file docker-compose.yaml up -d
```

Review the release notes for configuration or API changes before updating.
