# API integration

Microblink Self-Hosted Core exposes the document verification, document
extraction, and barcode extraction APIs.

| Operation             | Endpoint                       |
| --------------------- | ------------------------------ |
| Document verification | `POST /api/v3/verify`          |
| Document extraction   | `POST /api/v3/extract`         |
| Barcode extraction    | `POST /api/v3/extract-barcode` |
| OpenAPI schema        | `GET /api/v3/schema.json`      |

The availability of the endpoints also depends on the selected
[deployment mode](deployment-modes.md) and
[MicroblinkCore license capability](licensing.md#license-behavior).

## Request format

V3 image requests use `multipart/form-data`. Images are uploaded as file parts.
Request configuration is sent as one JSON object in a multipart part named
`configuration`.

Whole-object example:

```text
configuration={"extraction":{"redactionSettings":{"globalMode":"FullResult"}}}
```

File-backed example:

```text
configuration=@config.json;type=application/json
```

Uploaded images must be JPEG or PNG, no larger than 25 MiB each, at least 32 by
32 pixels, and no more extreme than a 20:1 aspect ratio. These are only the
technical input requirements. Consult our
[documentation website](https://docs.microblink.com/verify) for guidance on
image quality for product performance.

The configuration part is limited to 1 MiB, and the complete multipart body is
limited to 76 MiB. Container admission and memory protection are described
under
[Memory and request limits](environment-variables.md#memory-and-request-limits).

Use `GET /api/v3/schema.json` as the authoritative request and response
contract. The runtime limits above apply in addition to what the OpenAPI schema
can express.

**Enum-shaped schema values are open**. The listed strings are the values known
to the installed version, while clients should preserve unknown strings
returned by future versions. Configuration requests must still use a listed
value.

The examples below use local image files. For a quick smoke test, download
sample images first:

```bash
curl --fail --location --output sample-front.jpg \
  https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_FRONT_new/SGP_ID_FRONT_sample.jpg
curl --fail --location --output sample-back.jpg \
  https://storage.googleapis.com/microblink-data-public/microblink-api/test-set/blinkid/SGP_ID_BACK_new/SGP_ID_BACK_sample.jpg
```

## Document verification

`POST /api/v3/verify` extracts document data and runs the enabled verification
checks.

```bash
curl -X POST http://localhost:8080/api/v3/verify \
  -F "imageFirstSide=@sample-front.jpg" \
  -F "imageSecondSide=@sample-back.jpg"
```

Use `verification.useCase.verificationPolicy` for a high-level policy choice:

```bash
curl -X POST http://localhost:8080/api/v3/verify \
  -F 'configuration={"verification":{"useCase":{"verificationPolicy":"HighAssurance"}}}' \
  -F "imageFirstSide=@sample-front.jpg" \
  -F "imageSecondSide=@sample-back.jpg"
```

Supported image combinations:

-   `imageFirstSide`
-   `imageFirstSide` and `imageSecondSide`
-   `imageFirstSide`, `imageSecondSide`, and `imageBarcode`

The response contains the verification verdict, failed checks, individual check
results, image assessment, pipeline information, runtime information, and the
shared extraction result.

## Document extraction

`POST /api/v3/extract` extracts document data without running document
verification.

```bash
curl -X POST http://localhost:8080/api/v3/extract \
  -F 'configuration={"extraction":{"redactionSettings":{"globalMode":"FullResult"}}}' \
  -F "imageFirstSide=@sample-front.jpg"
```

Supported image combinations:

-   `imageFirstSide`
-   `imageFirstSide` and `imageSecondSide`
-   `imageSecondSide`
-   `imageFirstSide`, `imageSecondSide`, and `imageBarcode`

For document processing, the optional `imageBarcode` is only meant to be used
when a Microblink SDK such as BlinkID provides it.

Barcode-only requests use `/api/v3/extract-barcode`.

The response contains:

-   `imageAssessment`, describing image capture and quality.
-   `extraction`, containing document classification, extracted fields,
    per-side results, and requested images.
-   `runtime`, containing runtime information for the request.
-   `configurationUsed`, containing the explicit and default settings used for
    extraction.

## Barcode extraction

`POST /api/v3/extract-barcode` scans and parses one barcode image without
document-side extraction or verification.

```bash
curl -X POST http://localhost:8080/api/v3/extract-barcode \
  -F 'configuration={"extraction":{"barcodeSettings":{"pdf417ScanningEnabled":true,"qrScanningEnabled":true}}}' \
  -F "image=@/path/to/barcode.jpg"
```

The endpoint accepts the `image`, `configuration`, and `traceId` multipart
parts. PDF417 and QR scanning are enabled by default. At least one barcode
symbology must remain enabled.

The response contains `extraction.processingStatus`, the parsed barcode under
`extraction.result.barcode`, applied settings under
`configurationUsed.extraction.barcodeSettings`, and runtime information. Set
`configuration.extraction.barcodeSettings.barcodeImageReturnEnabled` to include
the extracted barcode image.

## Configuration

V3 settings are supplied only inside the multipart `configuration` JSON object.
Unsupported or misspelled settings return a structured HTTP `400` response
containing the offending path.

Verification settings belong under:

-   `verification.settings`
-   `verification.useCase`

## Validation errors

Invalid V3 request configuration returns a structured HTTP `400` response:

```json
{
    "message": "Invalid parameter in request.",
    "errors": [
        {
            "code": "InvalidParameter",
            "path": "verification.settings.screenPresenceSensitivity",
            "reason": "This parameter is invalid for the V3 multipart request schema."
        }
    ]
}
```

Clients can use `path` to identify the invalid request field and `reason` for
the diagnostic text.

Validation error codes are:

-   `InvalidParameter`
-   `InvalidParameterValue`
-   `InvalidParameterCombination`
-   `DuplicateParameter`
-   `InvalidRequestFormat`

Other operational responses include:

-   HTTP `400` when `/api/v3/verify` is called in
    [`Extract` mode](deployment-modes.md#extraction).
-   HTTP `403` when the
    [active license](licensing.md#license-behavior) does not permit document
    verification.
-   HTTP `429` when the instance has reached its configured request capacity;
    see [Queueing and backpressure](scaling.md#queueing-and-backpressure).
