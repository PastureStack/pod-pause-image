# PastureStack Pod Pause Image

A small pod-infrastructure image that keeps a container alive, reaps orphaned child processes, and exits cleanly when it receives `SIGTERM` or `SIGINT`.

PastureStack is an independent community effort to preserve, audit, and modernize the Rancher 1.6 ecosystem. It is not affiliated with or endorsed by Rancher Labs or SUSE.

**Origin:** This is an independent Ubuntu 26.04 compatibility implementation. No public upstream repository could be verified, so it is intentionally not represented as a GitHub fork.

## Release image

The reviewed `linux/amd64` release used by the catalog is:

```text
ghcr.io/pasturestack/pod-pause-image:v3.0.2
```

The catalog uses this semantic version tag. Release evidence records the immutable digest separately so a long digest never appears in the user interface.

## Build

```sh
docker build --pull \
  --build-arg IMAGE_VERSION=v3.0.2 \
  --build-arg SOURCE_REVISION="$(git rev-parse HEAD)" \
  -t ghcr.io/pasturestack/pod-pause-image:v3.0.2 .
```

The runtime base is pinned to the reviewed Ubuntu 26.04 `linux/amd64` manifest. The build stage uses the HTTPS Ubuntu snapshot and exact direct-package versions recorded in [`ubuntu-apt.lock`](ubuntu-apt.lock). The final image carries the resolved builder toolchain, builder package, and runtime package manifests under `/usr/share/pasturestack/manifests/`; CI also records builder and runtime image inspections, CycloneDX SBOMs, vulnerability reports, and signal-handling smoke tests as a 30-day review artifact. Runtime High and Critical findings are rejected. The non-shipping builder additionally rejects every High or Critical finding except Ubuntu `linux-libc-dev` kernel-header records for which the vendor has not published a fixed package; those records remain explicit review evidence and become blocking as soon as a fixed version exists.

## Smoke test

```sh
docker run -d --name pod-pause-poc ghcr.io/pasturestack/pod-pause-image:v3.0.2
docker inspect --format '{{.State.Running}} {{.Config.User}}' pod-pause-poc
docker stop --time 5 pod-pause-poc
docker inspect --format '{{.State.ExitCode}}' pod-pause-poc
docker rm pod-pause-poc
```

Expected results are `true 65532:65532`, a graceful stop within five seconds, and exit code `0`. Repeat the stop test to detect signal timing regressions.

## Compatibility status

The image preserves the pod-infrastructure process contract required by the PastureStack Kubernetes 1.12 catalog. Isolated validation does not replace the catalog deployment gate: the release must also pass a real pod-sandbox test on the supported Docker host before the catalog is published.

See [COMPATIBILITY.md](COMPATIBILITY.md) for retained contracts and [ORIGIN.md](ORIGIN.md) for provenance. This project is licensed under Apache-2.0; see [LICENSE](LICENSE).
