# Compatibility Contracts

The PastureStack repository and future image use the name `pod-pause-image`. The following historical references may still appear in documentation or integration evidence because they identify compatibility targets rather than current branding:

- the legacy 1.6 management stack and its Kubernetes catalog;
- the historical pod-infrastructure image contract recorded in the private migration knowledge base;
- existing catalog templates that still select a pre-PastureStack image.

The pause process itself has no product-specific API, environment variable, label, or localization contract. The integration gate is behavioral: it must remain running, reap child processes, and stop cleanly under the target Kubernetes and Docker versions.

The catalog release gate requires isolated container tests, a Kubernetes 1.12 pod-sandbox test, and rollback validation on the supported legacy host matrix. The semantic image tag is shown in the catalog; its immutable digest is retained only in release evidence.
