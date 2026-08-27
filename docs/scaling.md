# Scaling

Processing capacity depends on the deployment mode, document types, input
images, enabled processing settings, and resources assigned to each instance.
There is no single replica or throughput recommendation that applies to every
deployment.

Start with the defaults supplied in the deployment package and test with
documents and request settings representative of expected traffic. Extraction
mode has a different resource profile from extraction with verification; see
[Deployment modes](deployment-modes.md).

## Instances and workers

Each on-prem instance contains its own API, processing workers, and runtime
models.

-   Add instances or Kubernetes replicas when sustained throughput must
    increase.
-   `WORKER_COUNT` controls the number of processing workers inside one
    instance; see
    [Workflow and capacity](environment-variables.md#workflow-and-capacity).
-   Increasing `WORKER_COUNT` without assigning the instance enough CPU and
    memory can reduce performance rather than improve it.
-   Extraction mode generally uses significantly fewer resources because it
    does not start the server-side verification model service.

## Queueing and backpressure

Each instance has its own bounded admission gate and in-memory queue. The
in-flight limit controls active document requests, while the queue limit
controls how many additional requests may wait for a processing slot. See the
[environment-variable reference](environment-variables.md#workflow-and-capacity)
for the supported controls and defaults.

Keep the internal queue at `0` or a small positive value. A small queue can
smooth a brief routing burst, but a large queue hides overload inside one
instance, consumes memory, and increases tail latency. When both admission
limits are full, the API returns HTTP `429 Too Many Requests`; callers should
retry with bounded exponential backoff and jitter.

Occasional `429` responses can occur during short bursts. Sustained `429`
responses are a capacity signal: add replicas or reduce the offered load rather
than growing the in-memory queue. For durable buffering, place an external
queue in front of the deployment as described under
[External queue-based scaling](#external-queue-based-scaling).

The [Docker Compose reference](docker-compose.md) defaults to fail-fast
queueing, while the [Helm chart](kubernetes.md#configure-the-release) allows one
waiting request per pod to absorb a short Kubernetes routing burst.

## Capacity signals

Evaluate these signals together:

-   sustained HTTP `429` responses, showing that admission capacity is full
-   CPU and memory utilization near the configured limits
-   response-time and queueing-latency growth under representative concurrency
-   failed readiness or frequent container replacement

The health endpoints and Kubernetes probes are described in
[Kubernetes and Helm](kubernetes.md#access-the-api). Memory admission behavior
is described under
[Memory and request limits](environment-variables.md#memory-and-request-limits).

## Estimating capacity

Use a representative test workload when estimating capacity:

-   Include the document types and image sizes expected in production.
-   Use the intended [deployment mode](deployment-modes.md) and
    [request configuration](api-integration.md#configuration).
-   Measure throughput and response time at the expected concurrency.
-   Confirm the [backpressure behavior](#queueing-and-backpressure) when traffic
    exceeds available capacity.

Use those results to choose instance resources, `WORKER_COUNT`, and the number
of instances. Apply them through the
[Docker Compose resource settings](docker-compose.md#compose-file) or
[Helm values](kubernetes.md#configure-the-release).

## Horizontal scaling strategies

### Fixed replicas

Run more than one instance for redundancy and increase the replica count when
the representative load test shows that sustained traffic exceeds available
capacity. This is the simplest strategy and should be the starting point for
most deployments.

### CPU-based autoscaling

Document processing is CPU-intensive, so Kubernetes CPU utilization can be a
useful autoscaling signal. Configure a nonzero minimum replica count, leave
enough headroom for new pods to start, and validate the target utilization
against real traffic. Processing time varies by document and configuration, so
CPU is an approximation rather than an exact request-rate signal.

### External queue-based scaling

Deployments with large or concentrated bursts can place a gateway and durable
queue in front of the product, then scale consumers from queue depth or message
rate with a system such as KEDA. This gives more direct control over sustained
bursts but adds infrastructure, retry, timeout, and request-correlation
responsibilities outside the Microblink on-prem API.

Keep the [per-instance internal queue](#queueing-and-backpressure) small with
every strategy. It is intended to smooth brief routing bursts, not to replace
an external durable queue.
