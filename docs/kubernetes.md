# Kubernetes and Helm

The Helm deployment runs one on-prem API container per pod.
Each pod contains the API, processing workers, and runtime models.

## Prerequisites

-   Kubernetes 1.19 or newer
-   `kubectl` configured for the target cluster
-   At least one Linux AMD64 worker node
-   Helm 3
-   A [license](licensing.md)
-   The image version listed in the product release
-   The chart bundled in the matching documentation revision

## Use the bundled chart

The complete reference chart and default values are included at
[`deploy/helm/blinkid-verify`](../deploy/helm/blinkid-verify/README.md). From
the repository root, inspect and validate them with:

```bash
helm show values ./deploy/helm/blinkid-verify
helm lint ./deploy/helm/blinkid-verify
```

## Create the license object

Create a Kubernetes Secret with the license values:

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: microblink-license
type: Opaque
stringData:
    LICENSE_KEY: <license-key>
    LICENSE_APPLICATION_ID: <application-id>
```

Apply it in the namespace where the chart will be installed:

```bash
kubectl apply -f license-secret.yaml
```

See [Licensing](licensing.md) for the runtime license behavior.

## Configure the release

Create a values file:

```yaml
auth:
    license:
        secretName: microblink-license
        createSecret: false

blinkIdVerify:
    replicaCount: 1

    image:
        repository: us-docker.pkg.dev/document-verification-public/on-prem/core
        tag: <image-version>

    resources:
        requests:
            cpu: "2"
            memory: 4Gi
        limits:
            cpu: "4"
            memory: 8Gi

    nodeSelector:
        kubernetes.io/arch: amd64

    env:
        DOCVER_WORKFLOW: ExtractAndVerify
        WORKER_COUNT: "2"
        MicroblinkInflightLimit: "2"
        MicroblinkQueueLimit: "1"
```

Set `<image-version>` to the version listed in the product release. Keep
`DOCVER_WORKFLOW: ExtractAndVerify` for document verification.
For document and barcode extraction without verification, set
`DOCVER_WORKFLOW: Extract` instead. See
[Deployment modes](deployment-modes.md) before changing the mode.
See [Environment variables](environment-variables.md) for all supported
runtime settings and image defaults.

The image default for `MicroblinkQueueLimit` is `0`. The chart uses `1` to absorb
one short Kubernetes routing burst per pod without creating a large internal
backlog. See
[Queueing and backpressure](scaling.md#queueing-and-backpressure) before
changing it.

The chart values also configure the Service, Ingress, probes, scheduling,
security contexts, writable temporary volumes, extra environment variables,
and additional Secret imports.

## Security and writable storage

The chart defaults run the container as non-root UID `65534` with a read-only
root filesystem, all Linux capabilities dropped, privilege escalation
disabled, and the runtime-default seccomp profile. The pod filesystem group
allows that user to write the mounted temporary volumes. Kubernetes API token
mounting is disabled because the product does not call the Kubernetes API.

Writable `emptyDir` volumes are mounted at `/tmp` and `/var/tmp`. Optional size
limits are available under `blinkIdVerify.volumes`; file logging adds a bounded
`/var/log` volume when enabled.

The chart's default pod termination grace period is 30 seconds. Keep it longer
than `MICROBLINK_SHUTDOWN_GRACE_SECONDS`, which defaults to 10 seconds, so the
container can stop all managed processes before Kubernetes sends `SIGKILL`.
See [Health and shutdown](environment-variables.md#health-and-shutdown) for the
container-side behavior.

## Logging

Standard output and standard error are enabled by default and should be
collected by the cluster logging system. Set:

```yaml
blinkIdVerify:
    logFiles:
        enabled: true
```

only when files under `/var/log` are also required. Enabling it mounts another
`emptyDir`; configure `blinkIdVerify.volumes.varLog.sizeLimit` to bound local
disk use.
See [Environment variables](environment-variables.md#logging-and-metrics) for
the generated filenames.

## Install the chart

```bash
helm install microblink-self-hosted \
  ./deploy/helm/blinkid-verify \
  --values values.yaml
```

Check the release and pods:

```bash
helm status microblink-self-hosted
kubectl get pods \
  --selector app.kubernetes.io/instance=microblink-self-hosted
```

The chart configures liveness and readiness checks using `/health/live` and
`/health/ready`.

## Access the API

The chart creates a Kubernetes Service on port `8080`. To test it directly:

```bash
kubectl port-forward service/microblink-self-hosted-blinkid-verify 8080:8080
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

If the release overrides generated resource names, find the Service by release
label:

```bash
kubectl get service \
  --selector app.kubernetes.io/instance=microblink-self-hosted
```

Connect the Service to the deployment's existing ingress or gateway when the
API must be reachable outside the cluster. The chart can also create an Ingress
when its Ingress values are enabled.

Continue with the [API integration](api-integration.md) examples after the
readiness check succeeds.

## Update the release

Set the intended image version and apply the updated values:

```bash
helm upgrade microblink-self-hosted \
  ./deploy/helm/blinkid-verify \
  --values values.yaml
```

Review the release notes for configuration or API changes before updating.

To return to the previous Helm revision:

```bash
helm history microblink-self-hosted
helm rollback microblink-self-hosted <revision>
```

## Capacity

Set `blinkIdVerify.resources`, `blinkIdVerify.replicaCount`, and `WORKER_COUNT`
using results from a representative load test. See
[Scaling](scaling.md#estimating-capacity) for the supported capacity signals
and general guidance.

Review the release notes for configuration or API changes before updating an
older deployment.
