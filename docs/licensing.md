# Licensing

The on-prem API requires a valid license. The runtime reads two values:

-   `LICENSE_KEY`
-   `LICENSE_APPLICATION_ID`

Both values are supplied when the license is issued.

## Docker Compose

Set the values in the environment file used by Docker Compose:

```dotenv
LICENSE_KEY=<license-key>
LICENSE_APPLICATION_ID=<application-id>
```

See [Docker Compose](docker-compose.md#compose-file) for the complete reference
deployment.

## Kubernetes

Store the same two values in a Kubernetes Secret:

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

The deployment must expose both Secret keys to the container as environment
variables. The bundled chart references an existing Secret with:

```yaml
auth:
    license:
        secretName: microblink-license
        createSecret: false
```

The chart can create the Secret when `createSecret` is enabled, but an existing
Secret avoids placing the license key in a Helm values file. See
[Kubernetes and Helm](kubernetes.md#create-the-license-object) for the
installation flow.

## License behavior

The Worker cannot become ready with an invalid license.

License capabilities are also checked per operation. An extraction-capable
license can use the extraction endpoints. `POST /api/v3/verify` returns HTTP
`403` when the active license does not include document verification.

License capability and runtime mode are independent; see
[Mode and license](deployment-modes.md#mode-and-license). API clients should
handle the operational responses listed under
[Validation errors](api-integration.md#validation-errors).
