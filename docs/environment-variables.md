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
MicroblinkInflightLimit=3
MicroblinkQueueLimit=2
```

Use the exact spelling and capitalization shown in this document. The Worker
and container scripts read several names directly from the Linux environment,
where names are case-sensitive.

`DOCVER_WORKFLOW` retains its existing name. Capacity and shutdown settings use
the `Microblink` names shown below.

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

| Variable                  | Image default      | Role                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `DOCVER_WORKFLOW`         | `ExtractAndVerify` | Selects the runtime mode. `Extract` disables `/api/v3/verify` and the checks that need the bundled verification models. `ExtractAndVerify` enables both. Any other value stops startup.                                                                                                                                                                                  |
| `WORKER_COUNT`            | derived            | Accepted and ignored. The container derives its Worker count from the CPU and memory it is given: `min(cpu / 2, (memory − 700 MiB) / 1000 MiB)`, at least one and at most eight. Each Worker holds its own copy of the verification models, about 1 GiB, which is why memory bounds it. Existing values are accepted so deployments need no editing.                     |
| `MicroblinkInflightLimit` | derived            | Maximum number of document requests admitted concurrently by the shared limiter, defaulting to one more than the Worker count: each Worker handles one request at a time, and the extra permit lets a request be read while another is being processed. The same limit covers the V2 and V3 document endpoints. Non-positive or invalid values fall back to the default. |
| `MicroblinkQueueLimit`    | `2`                | Maximum number of requests waiting for an admission permit. `0` rejects excess requests immediately with HTTP `429`; the default of `2` absorbs a short burst, adding at most about two request times of waiting.                                                                                                                                                        |

A container runs one or more Workers, derived from its CPU and memory as described
above, and each holds its own copy of the verification models. Giving a container
more CPU without more memory will not add Workers, because memory is the binding
constraint: measured peak usage is about 1.6 GiB with one Worker, 2.6 GiB with two
and 4.4 GiB with four. Adding capacity beyond that means adding instances or
Kubernetes replicas; size each one with a representative workload as described in
[Scaling](scaling.md).

Keep `MicroblinkQueueLimit` small in Kubernetes and add replicas for sustained
load. The image default is `2`, which smooths a short routing burst per pod. For
durable buffering, place a shared queue or gateway in front of multiple
instances and scale consumers from the external queue. See
[Queueing and backpressure](scaling.md#queueing-and-backpressure) for the
complete overload strategy.

A larger bounded internal queue can be useful for a single Docker Compose
instance when callers have sufficiently long timeouts, but it should remain
small enough to keep overload visible.

## Memory limits

The container holds one copy of the verification models, so its memory use is
dominated by a fixed cost paid at startup rather than by per-request work. Set a
Docker or Kubernetes memory limit that fits that baseline with headroom, and
confirm it with a representative load test as described in
[Estimating capacity](scaling.md#estimating-capacity). A container given too
little memory reports the shortfall at startup and stops, rather than starting
and then refusing requests.

The concurrency limiter covers all document-processing endpoints that share the
same in-container Worker.

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

The supervisor treats the API and every Worker as one unit. If any managed component exits unexpectedly, the
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

## Model execution

The verification models run inside each Worker process. There is no separate
model-serving container, no serving endpoint to point at, and no serving-side
batching or thread-count variables to set: the runtime's own execution settings
are fixed in the image so that results do not depend on deployment tuning.

Earlier versions ran the models in a bundled TensorFlow Serving process and
exposed variables to tune it and to choose how the Workers checked its
readiness. Those variables no longer exist. Any of them left set in an existing
deployment are ignored and can be removed.

What governs model capacity now is the Worker count and the memory each Worker
needs for its own copy of the models, described under
[Workflow and capacity](#workflow-and-capacity) and
[Sizing an instance](scaling.md#sizing-an-instance). Extraction-only deployments
do not load the verification models at all; see
[Deployment modes](deployment-modes.md#extraction).

## Image-owned variables

The image also sets or derives values that define its internal topology and
runtime behavior. They are listed here to make the container contract explicit,
but they are not deployment tuning controls.

| Variable                         | Image value                                                      | Role                                                                                                                        |
| -------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `ASPNETCORE_URLS`                | `http://+:8080`                                                  | Binds the .NET API inside the container.                                                                                    |
| `API_PORT`                       | `8080`                                                           | Documents the internal API port used when the image is built. Changing it at runtime does not recalculate other values.     |
| `API_BASE_URL`                   | `http://localhost:8080`                                          | Internal queue endpoint used by Workers.                                                                                    |
| `RESOURCES_PATH`                 | `/app/res`                                                       | Bundled recognition-resource directory.                                                                                     |
| `SCHEMA_PATH`                    | `/app/Backend/Schemas/document-verification-request.schema.json` | Bundled internal request schema used by Workers.                                                                            |
| `DOTNET_gcServer`                | `1`                                                              | Enables server GC for the API process.                                                                                      |
| `DOTNET_GCDynamicAdaptationMode` | `1`                                                              | Enables dynamic GC adaptation for changing container load.                                                                  |
| `DOTNET_GCConserveMemory`        | `1`                                                              | Biases the API GC toward conserving memory.                                                                                 |
| `DOTNET_GCRetainVM`              | `0`                                                              | Allows released GC segments to be returned to the operating system.                                                         |
| `DOCVER_ONNX_INTRAOP_THREADS`    | derived                                                          | Inference threads each Worker may use, derived as the container's CPU allocation divided by the Worker count, at least one. |
| `SSL_CERT_FILE`                  | `/etc/ssl/certs/ca-certificates.crt`                             | CA bundle used by native TLS clients.                                                                                       |
| `CURL_CA_BUNDLE`                 | `/etc/ssl/certs/ca-certificates.crt`                             | CA bundle used by curl-compatible HTTP clients.                                                                             |

The Worker launcher derives `HEALTH_PORT` from `HEALTH_PORT_BASE` and assigns
`WORKER_INDEX` for the Worker process. Values set
on the container for those two variables are overwritten.

Changing `API_BASE_URL`, the bundled resource paths, or the internal serving
endpoints turns the deployment into a different topology and is outside the
supported single-image configuration.

See [Docker Compose](docker-compose.md) and
[Kubernetes and Helm](kubernetes.md) for deployment-specific configuration
syntax. Keep license values in a secret as described in
[Licensing](licensing.md).
