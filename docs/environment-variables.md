# Environment variables

Microblink on-prem API is configured through container environment
variables. This reference separates supported deployment settings from the
variables that wire the components inside the single image together.

## Quick reference

A typical deployment only needs the license, and optionally workflow:

```dotenv
LICENSE_KEY=<license-key>
LICENSE_APPLICATION_ID=<application-id>
DOCVER_WORKFLOW=ExtractAndVerify
```

For a bounded burst queue with explicit admission limits:

```dotenv
MicroblinkInflightLimit=2
MicroblinkQueueLimit=1
MicroblinkMemoryGuardPercent=95
```

Use the exact spelling and capitalization shown in this document. The Worker
and container scripts read several names directly from the Linux environment,
where names are case-sensitive.

`DOCVER_WORKFLOW` retains its existing name. Capacity, memory-guard, and
shutdown settings use the `Microblink` names shown below.

.NET configuration sections use a double underscore in environment variables.
For example, the `Logging:LogLevel:Default` configuration key is written as
`Logging__LogLevel__Default` in Docker Compose or Kubernetes. Only set
variables presented as deployment settings below; the
[image-owned variables](#image-owned-variables) are informational and must not
be overridden.

## Required license variables

| Variable                 | Default | Role                                                                                                                                |
| ------------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `LICENSE_KEY`            | None    | License key used by every Worker. Keep it in a secret store and do not put it in an image, Compose file, Helm values file, or logs. |
| `LICENSE_APPLICATION_ID` | None    | Application ID associated with the license. Supply it from the same secret as the license key.                                      |

Both values are required. A Worker with missing or invalid license
configuration does not become ready. License capabilities are checked
separately from the selected workflow; see [Licensing](licensing.md) and
[Deployment modes](deployment-modes.md#mode-and-license).

## Workflow and capacity

| Variable                  | Image default      | Role                                                                                                                                                                                                                    |
| ------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DOCVER_WORKFLOW`         | `ExtractAndVerify` | Selects the runtime mode. `Extract` starts the API and Workers without TensorFlow Serving and disables `/api/v3/verify`. `ExtractAndVerify` also starts the bundled verification models. Any other value stops startup. |
| `WORKER_COUNT`            | `2`                | Number of Worker processes in the container. It must be a positive integer. It also controls the default request concurrency and the number of Workers required for API readiness.                                      |
| `MicroblinkInflightLimit` | `WORKER_COUNT`     | Maximum number of document requests admitted concurrently by the shared limiter. The same limit covers the V2 and V3 document endpoints. Non-positive or invalid values fall back to the default.                       |
| `MicroblinkQueueLimit`    | `0`                | Maximum number of requests waiting for an admission permit. `0` rejects excess requests immediately with HTTP `429`; a small positive value absorbs short bursts at the cost of additional memory and latency.          |

`WORKER_COUNT` is capacity, not a throughput guarantee. Increasing it gives the
container more simultaneous processing slots, but each Worker also consumes CPU
and memory. Size the container and tune the worker count with a representative
workload as described in [Scaling](scaling.md).

Keep `MicroblinkQueueLimit` small or `0` in Kubernetes and add replicas for
sustained load. The image default is `0`; the bundled reference chart sets it
to `1` to smooth one short routing burst per pod. For durable buffering, place
a shared queue or gateway in front of multiple instances and scale consumers
from the external queue. See
[Queueing and backpressure](scaling.md#queueing-and-backpressure) for the
complete overload strategy.

A larger bounded internal queue can be useful for a single Docker Compose
instance when callers have sufficiently long timeouts, but it should remain
small enough to keep overload visible.

## Memory and request limits

| Variable                                         | Image default | Role                                                                                                                                                                                                                                  |
| ------------------------------------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MicroblinkMemoryGuardPercent`                   | `95`          | Starts rejecting document requests with HTTP `429` when current container memory use reaches this percentage of the detected cgroup limit. `0` disables the guard. The guard is also inactive when no finite cgroup limit is visible. |
| `MicroblinkMemoryGuardReservationFactor`         | `10`          | Multiplies request `Content-Length` to estimate the memory reserved by an admitted request. `0` disables reservation-based admission while leaving the usage threshold active.                                                        |
| `MicroblinkMemoryGuardUnknownContentLengthBytes` | `20971520`    | Base reservation, in bytes, for a request without `Content-Length`. The reservation factor is applied to this value.                                                                                                                  |

The percentage threshold and request reservations protect the same admission
budget; they are not alternatives. The reservation factor does not allocate
memory. It estimates a request's peak memory cost for admission. A request is
admitted only when current container memory usage, existing outstanding
reservations, and the new request reservation fit below the percentage
threshold.

For example, a 10 GiB container with a 95% threshold has a 9,728 MiB admission
budget. If current usage is 8,192 MiB and outstanding requests reserve 1,024
MiB, a 50 MiB request with the default factor reserves another 500 MiB. The
total is 9,716 MiB, so the request is admitted. Another identical request would exceed
the threshold and receive HTTP `429`.

The memory guard depends on a container memory limit. Without one, the API
cannot calculate the percentage threshold. Always set a Docker or Kubernetes
memory limit in production. Use a representative load test as described in
[Estimating capacity](scaling.md#estimating-capacity).

The concurrency limiter and memory guard protect all document-processing
endpoints that share the same in-container Worker pool.

Caller, ingress, load-balancer, and API timeouts should agree. Increasing only
one timeout does not make an end-to-end request live longer if another layer
closes the connection first. Client behavior for overload responses is covered
under [Queueing and backpressure](scaling.md#queueing-and-backpressure).

## Health and shutdown

| Variable                            | Image default   | Role                                                                                                                                                                                                             |
| ----------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HEALTH_PORT_BASE`                  | `18080`         | First Worker health-server port. Worker index `N` listens on `HEALTH_PORT_BASE + N`. These ports are used inside the container and do not normally need to be published.                                         |
| `WorkerHealth__Path`                | `/health/ready` | Worker endpoint polled by the API readiness check. Keep the default for the bundled Worker.                                                                                                                      |
| `MICROBLINK_SHUTDOWN_GRACE_SECONDS` | `10`            | Seconds the supervisor waits after forwarding a termination signal before killing remaining service process groups. It must be a non-negative integer. Align the orchestrator termination grace period above it. |

The supervisor treats the API, every Worker, and TensorFlow Serving when
enabled as one unit. If any managed component exits unexpectedly, the
supervisor stops the others and exits so Docker or Kubernetes can replace the
whole instance. See the
[Kubernetes probe configuration](kubernetes.md#access-the-api) and
[Docker Compose health check](docker-compose.md#start-the-deployment).

## Logging and metrics

| Variable                                  | Image default | Role                                                                                                                                                                                                       |
| ----------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LOG_FILES_ENABLED`                       | `0`           | Standard output and error are always used. Set to `1`, `TRUE`, `YES`, or `ON` to also mirror component logs under `/var/log`; the directory must be writable and should be backed by a volume if retained. |
| `Logging__LogLevel__Default`              | `Information` | Default .NET API log level.                                                                                                                                                                                |
| `Logging__LogLevel__Microsoft.AspNetCore` | `Warning`     | ASP.NET Core framework log level. Other .NET logging categories can be overridden with the same `Logging__LogLevel__<Category>` pattern.                                                                   |

The optional files are:

-   `/var/log/api.log`
-   `/var/log/tf-serving.log` in `ExtractAndVerify`
-   `/var/log/worker-N.out.log`
-   `/var/log/worker-N.err.log`

Container log collection remains the recommended production setup. Deployment
instructions are in [Docker Compose logs](docker-compose.md#logs-and-status)
and [Kubernetes logging](kubernetes.md#logging).

## API access and CORS

| Variable           | Image default | Role                                                                                                              |
| ------------------ | ------------- | ----------------------------------------------------------------------------------------------------------------- |
| `Api__CorsOrigins` | `*`           | Comma-separated allowed browser origins, or `*`. Set explicit origins when browser clients call the API directly. |
| `Api__CorsMethods` | `*`           | Comma-separated allowed CORS methods, or `*`.                                                                     |
| `Api__CorsHeaders` | `*`           | Comma-separated allowed CORS request headers, or `*`.                                                             |

CORS is a browser policy; it is not authentication or network access control.
Restrict exposure with the deployment's Service, Ingress, firewall, or gateway.
The public endpoints and request formats are described in
[API integration](api-integration.md).

The API listens on container port `8080`. Change the host, Service, or Ingress
port mapping instead of changing the internal port:

```bash
docker run -p 9090:8080 ...
```

Several image-owned variables assume port `8080`, so changing only one internal
port variable can disconnect the Workers from the API.

## Bundled model-serving controls

These variables configure TensorFlow Serving and Worker readiness in
`ExtractAndVerify`. The published image supplies working defaults. Change them
only as part of a tested deployment-specific tuning exercise.

They do not apply to extraction-only deployments; see
[Deployment modes](deployment-modes.md#extraction).

| Variable                             | Image default             | Role                                                                                                                                                        |
| ------------------------------------ | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TF_SERVING_ENABLE_BATCHING`         | `1`                       | Enables TensorFlow Serving batching only when the value is exactly `1`.                                                                                     |
| `TF_SERVING_BATCHING_CONFIG`         | `/models/batching.config` | Batching parameters passed to TensorFlow Serving when batching is enabled. The path must exist inside the container.                                        |
| `TF_NUM_INTRAOP_THREADS`             | `4`                       | TensorFlow intra-operation thread count.                                                                                                                    |
| `TF_NUM_INTEROP_THREADS`             | `2`                       | TensorFlow inter-operation thread count.                                                                                                                    |
| `OMP_NUM_THREADS`                    | `4`                       | OpenMP thread count available to model-serving runtime libraries.                                                                                           |
| `MODEL_SERVING_READINESS_MODE`       | `tensorflow-signature`    | Worker readiness method. The default verifies every configured model over the same gRPC serving path used for inference.                                    |
| `MODEL_SERVING_READINESS_TIMEOUT_MS` | `1000`                    | Per-model readiness request timeout in milliseconds.                                                                                                        |
| `TF_SERVING_READY_FILE`              | Unset                     | Optional path used with `tensorflow-ready-file` readiness. The launcher creates the file after TensorFlow Serving reports that model loading has completed. |

The supported readiness-mode families are:

-   `tensorflow-signature`, the image default and strongest end-to-end check
-   `tensorflow-rest`, which checks each model through the REST status API
-   `tensorflow-ready-file`, which combines a startup marker file with a TCP
    connection check
-   any other value, which falls back to a TCP connection check

## Image-owned variables

The image also sets or derives values that define its internal topology and
runtime behavior. They are listed here to make the container contract explicit,
but they are not deployment tuning controls.

| Variable                         | Image value                                                      | Role                                                                                                                    |
| -------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ASPNETCORE_URLS`                | `http://+:8080`                                                  | Binds the .NET API inside the container.                                                                                |
| `API_PORT`                       | `8080`                                                           | Documents the internal API port used when the image is built. Changing it at runtime does not recalculate other values. |
| `API_BASE_URL`                   | `http://localhost:8080`                                          | Internal queue endpoint used by Workers.                                                                                |
| `RESOURCES_PATH`                 | `/app/res`                                                       | Bundled recognition-resource directory.                                                                                 |
| `SCHEMA_PATH`                    | `/app/Backend/Schemas/document-verification-request.schema.json` | Bundled internal request schema used by Workers.                                                                        |
| `DOTNET_gcServer`                | `1`                                                              | Enables server GC for the API process.                                                                                  |
| `DOTNET_GCDynamicAdaptationMode` | `1`                                                              | Enables dynamic GC adaptation for changing container load.                                                              |
| `DOTNET_GCConserveMemory`        | `1`                                                              | Biases the API GC toward conserving memory.                                                                             |
| `DOTNET_GCRetainVM`              | `0`                                                              | Allows released GC segments to be returned to the operating system.                                                     |
| `SSL_CERT_FILE`                  | `/etc/ssl/certs/ca-certificates.crt`                             | CA bundle used by native TLS clients.                                                                                   |
| `CURL_CA_BUNDLE`                 | `/etc/ssl/certs/ca-certificates.crt`                             | CA bundle used by curl-compatible HTTP clients.                                                                         |

The Worker launcher derives `HEALTH_PORT` from `HEALTH_PORT_BASE` and assigns
`WORKER_INDEX` from `0` through `WORKER_COUNT - 1` for each process. Values set
on the container for those two variables are overwritten.

Changing `API_BASE_URL`, the bundled resource paths, or the internal serving
endpoints turns the deployment into a different topology and is outside the
supported single-image configuration.

See [Docker Compose](docker-compose.md) and
[Kubernetes and Helm](kubernetes.md) for deployment-specific configuration
syntax. Keep license values in a secret as described in
[Licensing](licensing.md).
