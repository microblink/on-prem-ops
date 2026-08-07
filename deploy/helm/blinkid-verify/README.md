# BlinkID Verify Helm chart

This reference chart deploys one BlinkID Verify self-hosted single-image
container per pod. Each container includes the API, Workers, and runtime models.
The image supports Linux AMD64 nodes.

For throughput, replica, and worker sizing, see
[Scaling](../../../docs/scaling.md).

## Install from this repository

Create the license Secret described in the
[Kubernetes guide](../../../docs/kubernetes.md#create-the-license-object),
then install the bundled chart from the repository root:

```bash
helm install microblink-self-hosted \
  ./deploy/helm/blinkid-verify \
  --set-string blinkIdVerify.image.tag=<image-version>
```

For a repeatable deployment, copy [values.yaml](values.yaml), change only the
required settings, and commit that deployment-specific values file to your
operations repository without license credentials:

```bash
helm upgrade --install microblink-self-hosted \
  ./deploy/helm/blinkid-verify \
  --values /path/to/values.yaml
```

## Important values

| Value                                       | Default                      | Role                                              |
| ------------------------------------------- | ---------------------------- | ------------------------------------------------- |
| `auth.license.secretName`                   | `microblink-license`         | Existing Secret containing both license keys.     |
| `auth.license.createSecret`                 | `false`                      | Creates the Secret from Helm values when enabled. |
| `blinkIdVerify.replicaCount`                | `1`                          | Number of single-image pods.                      |
| `blinkIdVerify.image.repository`            | Public single-image registry | Container image repository.                       |
| `blinkIdVerify.image.tag`                   | Chart application version    | Product image version.                            |
| `blinkIdVerify.resources`                   | 2–4 CPU, 4–8 GiB             | Pod requests and limits.                          |
| `blinkIdVerify.env.DOCVER_WORKFLOW`         | `ExtractAndVerify`           | Selects verification or extraction-only mode.     |
| `blinkIdVerify.env.WORKER_COUNT`            | `2`                          | Worker processes per pod.                         |
| `blinkIdVerify.env.MicroblinkInflightLimit` | `2`                          | Concurrent requests admitted per pod.             |
| `blinkIdVerify.env.MicroblinkQueueLimit`    | `1`                          | Small per-pod routing-burst queue.                |
| `blinkIdVerify.logFiles.enabled`            | `false`                      | Mirrors logs to an optional `/var/log` volume.    |
| `blinkIdVerify.ingress.enabled`             | `false`                      | Creates an Ingress from the configured hosts.     |

Only use `blinkIdVerify.extraEnv` for variables listed in the
[public environment-variable reference](../../../docs/environment-variables.md).
The image supplies its internal transport, timeout, metadata, and model-serving
configuration.

See the complete [Kubernetes and Helm guide](../../../docs/kubernetes.md) for
security, probes, upgrades, rollback, and capacity guidance. For request
admission and replica strategy, see
[Queueing and backpressure](../../../docs/scaling.md#queueing-and-backpressure).
