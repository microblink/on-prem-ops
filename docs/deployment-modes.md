# Deployment modes

The on-prem API uses `DOCVER_WORKFLOW` to select which runtime components are
started.

| Mode                      | `DOCVER_WORKFLOW` value | Available operations                             | Server-side verification models |
| ------------------------- | ----------------------- | ------------------------------------------------ | ------------------------------- |
| Extraction + Verification | `ExtractAndVerify`      | Extraction, barcode extraction, and verification | Started                         |
| Extraction                | `Extract`               | Document extraction and barcode extraction       | Not started                     |

`ExtractAndVerify` is the default when `DOCVER_WORKFLOW` is not set. Any other
value causes container startup to fail.

Use `ExtractAndVerify` by default for the strongest available protection and
comprehensive document verification. This mode requires a
license with document-verification capability and enough memory for the bundled
verification models. Validate the selected mode with the process described in
[Estimating capacity](scaling.md#estimating-capacity).

## Extraction + Verification

`ExtractAndVerify` enables:

-   [`POST /api/v3/verify`](api-integration.md#document-verification)
-   [`POST /api/v3/extract`](api-integration.md#document-extraction)
-   [`POST /api/v3/extract-barcode`](api-integration.md#barcode-extraction)

This mode starts the server-side verification models. The active
[license](licensing.md#license-behavior) must include document verification. If
it does not, verification requests return HTTP `403`.

```dotenv
DOCVER_WORKFLOW=ExtractAndVerify
```

## Extraction

`Extract` is available for deployments that are intentionally licensed and
configured for extraction or barcode extraction without document verification:

-   [`POST /api/v3/extract`](api-integration.md#document-extraction)
-   [`POST /api/v3/extract-barcode`](api-integration.md#barcode-extraction)

The model files remain in the image, but the server-side verification model
service is not started. A request to `POST /api/v3/verify` returns HTTP `400`
because the endpoint is disabled in this mode.

```dotenv
DOCVER_WORKFLOW=Extract
```

## Mode and license

The deployment mode and license have separate roles:

-   `DOCVER_WORKFLOW` controls which runtime components and endpoints are
    enabled.
-   The license controls which operations the runtime is
    permitted to perform.

Configure both for the capabilities expected from the deployment.
The supported environment syntax and default are documented under
[Workflow and capacity](environment-variables.md#workflow-and-capacity).
