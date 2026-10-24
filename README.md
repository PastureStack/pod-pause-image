# PastureStack Pod Pause Image

Linux runtime **`v3.0.6`** consumes verified Ubuntu security backports without adding packages or changing the existing coreutils provider.

The runtime recipe applies the qualified Ubuntu 26.04 backport bundle only to already-installed packages and preserves the selected coreutils provider. The immutable bundle digest and final-image checks are pending. Bundle manifests, qualification, exact-version OpenVEX, source inputs and install/verify receipts are retained under `/usr/share/pasturestack/security/ubuntu-backports/`; raw scan evidence and the existing full-severity release policy remain required.

A small pod-infrastructure image that keeps a container alive, reaps orphaned child processes, and exits cleanly when it receives `SIGTERM` or `SIGINT`.

PastureStack is an independent community effort to preserve, audit, and modernize the Rancher 1.6 ecosystem. It is not affiliated with or endorsed by Rancher Labs or SUSE.

**Origin:** This is an independent Ubuntu 26.04 compatibility implementation. No public upstream repository could be verified, so it is intentionally not represented as a GitHub fork.

## Maintained image

After publication, the candidate `linux/amd64` runtime uses the pure numeric coordinate:

```text
ghcr.io/pasturestack/pod-pause-image:v3.0.6
```

Product identity and provenance are carried by the package name, OCI labels,
SBOM, and attestations rather than a text qualifier in the tag. Existing
Catalog revisions remain immutable; maintained Catalog revisions use this
numeric successor after its release and integration gates pass.

## Build

The recipe installs the SHA256-pinned official Ubuntu CA security update in
the build stage after the locked snapshot. Both stages apply the existing-package
security micro-updates in `ubuntu-security-packages.lock` from the signed
2026-10-23 Ubuntu 26.04 snapshot, without adding or removing packages. This
includes OpenSSL and the available libc, compression, utility and builder-header
fixes; the resolved manifests remain part of the image. The runtime has no CA
package or TLS client dependency; its temporary apt trust bundle is removed.
This does not change pause-process,
signal-handling, privilege or pod-sandbox behavior.

```sh
docker build --pull \
  --build-arg IMAGE_VERSION=v3.0.6 \
  --build-arg SOURCE_REVISION="$(git rev-parse HEAD)" \
  -t local/pasturestack/pod-pause-image:v3.0.6 .
```

The runtime base is pinned to the reviewed Ubuntu 26.04 `linux/amd64` manifest. The build stage uses the HTTPS Ubuntu snapshot and exact direct-package versions recorded in [`ubuntu-apt.lock`](ubuntu-apt.lock). The final image carries the resolved builder toolchain, builder package, and runtime package manifests under `/usr/share/pasturestack/manifests/`; CI also records builder and runtime image inspections, CycloneDX SBOMs, vulnerability reports, and signal-handling smoke tests as a 30-day review artifact.

The release gate checks the complete runtime vulnerability report. Any available fixed version, unknown severity, High or Critical finding, or unreviewed finding blocks release. Only exact Low or Medium package findings with recorded official no-fix evidence in [`.github/runtime-unfixed.json`](.github/runtime-unfixed.json) may remain; this is tracked residual risk, not a vulnerability-free claim. The non-shipping builder also rejects every finding with an available fixed version and every High or Critical finding except Ubuntu `linux-libc-dev` kernel-header records for which the vendor has not published a fixed package. Those header records remain explicit review evidence and become blocking as soon as a fixed version exists.

## Smoke test

```sh
docker run -d --name pod-pause-poc local/pasturestack/pod-pause-image:v3.0.6
docker inspect --format '{{.State.Running}} {{.Config.User}}' pod-pause-poc
docker stop --time 5 pod-pause-poc
docker inspect --format '{{.State.ExitCode}}' pod-pause-poc
docker rm pod-pause-poc
```

Expected results are `true 65532:65532`, a graceful stop within five seconds, and exit code `0`. Repeat the stop test to detect signal timing regressions.

## Compatibility status

The image preserves the pod-infrastructure process contract required by the PastureStack Kubernetes 1.12 catalog. Isolated validation does not replace the catalog deployment gate: the release must also pass a real pod-sandbox test on the supported Docker host before the catalog is published.

See [COMPATIBILITY.md](COMPATIBILITY.md) for retained contracts and [ORIGIN.md](ORIGIN.md) for provenance. This project is licensed under Apache-2.0; see [LICENSE](LICENSE).
