# BlinkID Verify Self-Hosted

This repository contains the public documentation and reference deployment
artifacts for the BlinkID Verify self-hosted image.

## Get started

-   Read the [self-hosted overview](docs/README.md).
-   Run the image with the bundled
    [Docker Compose reference](deploy/docker-compose/README.md).
-   Deploy to Kubernetes with the bundled
    [Helm chart](deploy/helm/blinkid-verify/README.md).

The container image is published at:

```text
us-docker.pkg.dev/document-verification-public/on-prem/core:<version>
```

Use the image version listed in the corresponding product release with the
chart bundled in the matching documentation revision. Both deployment examples
require a Linux AMD64 host or node and a MicroblinkCore license key and
application ID.

## Repository layout

```text
.
├── .github/                    Public-repository validation
├── deploy/
│   ├── docker-compose/         Runnable Docker Compose reference
│   └── helm/blinkid-verify/    Reference Helm chart and default values
└── docs/                       Integration and operations documentation
```

General product documentation and release notes are available at
[docs.microblink.com/verify](https://docs.microblink.com/verify).
