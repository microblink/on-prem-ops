# Microblink Self-Hosted Core

Microblink Self-Hosted Core packages Microblink document extraction and
verification capabilities for customer-managed environments. It is distributed
as a single container image containing the API, processing workers, and runtime
models.

The same image supports two modes:

-   **Extraction + Verification** for extraction and/or document verification.
-   **Extraction** for document and barcode extraction.

The runtime uses a MicroblinkCore license. The enabled operations depend on the
license capabilities and the selected [deployment mode](deployment-modes.md).

## Distribution

-   Container image:
    `us-docker.pkg.dev/document-verification-public/on-prem/core:<version>`
-   Bundled Helm chart:
    [`deploy/helm/blinkid-verify`](../deploy/helm/blinkid-verify/README.md)
-   Bundled Docker Compose deployment:
    [`deploy/docker-compose`](../deploy/docker-compose/README.md)

Use the image version listed in the product release with the deployment
artifacts bundled in the matching documentation revision.

## Quickstart

1. Obtain the `LICENSE_KEY` and `LICENSE_APPLICATION_ID` values supplied with
   the [MicroblinkCore license](licensing.md).
2. Keep the default `ExtractAndVerify` mode for document verification, or choose
   another mode as described in [Deployment modes](deployment-modes.md).
3. Start the product with [Docker Compose](docker-compose.md) or
   [Kubernetes and Helm](kubernetes.md).
4. Wait for the readiness endpoint:

    ```bash
    curl --fail http://localhost:8080/health/ready
    ```

5. Send a verification request:

    ```bash
    curl --fail --location --output sample-front.jpg \
      https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_FRONT_new/SGP_ID_FRONT_sample.jpg
    curl --fail --location --output sample-back.jpg \
      https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_BACK_new/SGP_ID_BACK_sample.jpg

    curl -X POST http://localhost:8080/api/v3/verify \
      -F "imageFirstSide=@sample-front.jpg" \
      -F "imageSecondSide=@sample-back.jpg"
    ```

    Extraction endpoints are also available when the license permits them:

    ```bash
    curl -X POST http://localhost:8080/api/v3/extract \
      -F "imageFirstSide=@sample-front.jpg"
    ```

The runtime serves its Self-Hosted OpenAPI document at
`GET /api/v3/schema.json`; see [API integration](api-integration.md) for request
formats and examples.

General product guidance is available at
[docs.microblink.com/verify](https://docs.microblink.com/verify), with published
changes under [release notes](https://docs.microblink.com/verify/release-notes).
Use the runtime OpenAPI document as the contract for the installed version.

## Documentation

### Understand and integrate

-   [Deployment modes](deployment-modes.md) explains verification-first and
    extraction-only operation.
-   [Licensing](licensing.md) explains credentials, Secrets, and capability
    enforcement.
-   [API integration](api-integration.md) covers endpoints, multipart requests,
    responses, and operational errors.

### Deploy

-   [Docker Compose](docker-compose.md) uses the bundled single-host reference.
-   [Kubernetes and Helm](kubernetes.md) uses the bundled chart and values.

### Operate

-   [Environment variables](environment-variables.md) is the supported
    customer-configuration reference.
-   [Scaling](scaling.md) covers capacity testing, queueing and backpressure,
    replicas, and autoscaling.
