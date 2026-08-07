# Docker Compose reference

This directory contains a runnable Docker Compose deployment for the BlinkID
Verify self-hosted single image.

1. Copy `.env.example` to `.env`.
2. Set the image version and license values in `.env`.
3. Start the deployment:

    ```bash
    docker compose up -d
    ```

4. Wait for readiness:

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

See the [Docker Compose guide](../../docs/docker-compose.md) for operational
guidance, the
[environment-variable reference](../../docs/environment-variables.md) for
supported customer configuration, and
[Scaling](../../docs/scaling.md#queueing-and-backpressure) for admission and
queue guidance.
