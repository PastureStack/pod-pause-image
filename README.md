# PastureStack Pod Pause Image

A small pod-infrastructure image that keeps a container alive, reaps orphaned child processes, and exits cleanly when it receives `SIGTERM` or `SIGINT`.

PastureStack is an independent community effort to preserve, audit, and modernize the Rancher 1.6 ecosystem. It is not affiliated with or endorsed by Rancher Labs or SUSE.

**Origin:** This is an independent Ubuntu 26.04 compatibility implementation. No public upstream repository could be verified, so it is intentionally not represented as a GitHub fork.

## Release image

The reviewed `linux/amd64` release used by the catalog is:

```text
ghcr.io/pasturestack/pod-pause-image:v3.0.1-pasturestack.1
```

The catalog uses this semantic version tag. Release evidence records the immutable digest separately so a long digest never appears in the user interface.

## Build

```sh
docker build --pull \
  --build-arg IMAGE_VERSION=v3.0.1-pasturestack.1 \
  --build-arg SOURCE_REVISION="$(git rev-parse HEAD)" \
  -t ghcr.io/pasturestack/pod-pause-image:v3.0.1-pasturestack.1 .
```

The runtime base is pinned to the reviewed Ubuntu 26.04 `linux/amd64` manifest. The build stage downloads compiler packages from the Ubuntu archive, so release evidence must still record the resulting image digest, SBOM, vulnerability scan, and runtime tests.

## Smoke test

```sh
docker run -d --name pod-pause-poc ghcr.io/pasturestack/pod-pause-image:v3.0.1-pasturestack.1
docker inspect --format '{{.State.Running}} {{.Config.User}}' pod-pause-poc
docker stop --time 5 pod-pause-poc
docker inspect --format '{{.State.ExitCode}}' pod-pause-poc
docker rm pod-pause-poc
```

Expected results are `true 65532:65532`, a graceful stop within five seconds, and exit code `0`. Repeat the stop test to detect signal timing regressions.

## Compatibility status

The image preserves the pod-infrastructure process contract required by the PastureStack Kubernetes 1.12 catalog. Isolated validation does not replace the catalog deployment gate: the release must also pass a real pod-sandbox test on the supported Docker host before the catalog is published.

See [COMPATIBILITY.md](COMPATIBILITY.md) for retained contracts and [ORIGIN.md](ORIGIN.md) for provenance. This project is licensed under Apache-2.0; see [LICENSE](LICENSE).
