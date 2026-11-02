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

-   Each instance sizes itself. It runs `min(cpu / 2, (memory - 700Mi) / 1000Mi)`
    processing workers, at least one and at most eight, because each worker holds
    its own copy of the verification models. `WORKER_COUNT` is accepted and
    ignored.
-   Give an instance CPU and memory together. More memory alone adds nothing;
    more CPU alone adds workers only if the memory is there to hold them.
-   Add instances or Kubernetes replicas when one instance's allocation is no
    longer enough.

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
[Kubernetes and Helm](kubernetes.md#access-the-api). Overload is shed by the
admission limiter described under
[Workflow and capacity](environment-variables.md#workflow-and-capacity); the
container's memory requirement is a fixed startup cost, covered under
[Memory limits](environment-variables.md#memory-limits).

## Sizing an instance

The figures below were measured on one instance processing a mixed corpus of
identity documents through `POST /api/v3/verify`, without returned images. Treat
them as a starting point and confirm them against your own documents and
hardware, as described under [Estimating capacity](#estimating-capacity).

| CPU | Memory | Workers | Response time (p95, unsaturated) | Sustained throughput |
| --- | ------ | ------- | -------------------------------- | -------------------- |
| 2   | 2Gi    | 1       | ~1.6 s                           | ~0.6 req/s           |
| 4   | 2Gi    | 1       | ~1.0 s                           | ~1.0 req/s           |
| 8   | 2Gi    | 1       | ~0.9 s                           | ~1.2 req/s           |
| 4   | 4Gi    | 2       | ~1.2 s                           | ~1.3 req/s           |
| 4   | 8Gi    | 2       | ~1.2 s                           | ~1.6 req/s           |
| 8   | 8Gi    | 4       | ~0.8 s                           | ~2.0 req/s           |

Three things follow from it.

**Memory sets the worker count, and nothing else.** Resident usage is about
1.6Gi with one worker, 2.6Gi with two and 4.4Gi with four, and it does not grow
into spare headroom: the same instance used the same memory whether it was given
2Gi or 8Gi. Memory beyond what the workers need is wasted.

**CPU shortens each request, up to a point.** A single request uses several cores
for inference, so response time falls from about 1.6 s at 2 CPU to 1.0 s at 4.
Past roughly four cores a single request runs out of parallel work, and further
CPU only helps if there are enough workers to use it.

**Throughput comes from workers, response time from CPU.** If requests are being
rejected, add memory so the instance can run more workers. If each request is too
slow, add CPU.

`2Gi` is the smallest supported memory limit for the verification workflow. An
instance given less reports the shortfall and stops at startup rather than
starting and then rejecting requests.

## Estimating capacity

Use a representative test workload when estimating capacity:

-   Include the document types and image sizes expected in production.
-   Use the intended [deployment mode](deployment-modes.md) and
    [request configuration](api-integration.md#configuration).
-   Measure throughput and response time at the expected concurrency.
-   Confirm the [backpressure behavior](#queueing-and-backpressure) when traffic
    exceeds available capacity.

Use those results to choose instance resources and the number
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
