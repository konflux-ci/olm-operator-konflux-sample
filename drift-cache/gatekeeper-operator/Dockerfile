# Build the manager binary
FROM registry.ci.openshift.org/stolostron/builder:go1.26-linux AS builder

ARG GOOS
ARG GOARCH
ARG LDFLAGS

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY main.go main.go
COPY api/ api/
COPY controllers/ controllers/
COPY pkg/ pkg/

# Build
RUN CGO_ENABLED=1 GOOS=${GOOS} GOARCH=${GOARCH} go build -mod=readonly -a -ldflags "${LDFLAGS}" -o manager main.go

# Copy to base image
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
WORKDIR /
COPY --from=builder /workspace/manager .
RUN mkdir licenses/
COPY LICENSE licenses/
USER 65532:65532

ENTRYPOINT ["/manager"]

LABEL name=gatekeeper/gatekeeper-rhel9-operator
LABEL summary="Red Hat Gatekeeper Operator"
LABEL description="The Gatekeeper Operator installs and configures Open Policy Agent Gatekeeper."
LABEL version=v3.21.0
LABEL maintainer="acm-component-maintainers@redhat.com"
LABEL com.redhat.component=gatekeeper-operator-container
LABEL io.openshift.tags="data,images"
LABEL io.k8s.display-name="Gatekeeper Operator"
LABEL io.k8s.description="The Gatekeeper Operator installs and configures Open Policy Agent Gatekeeper."
LABEL cpe="cpe:/a:redhat:gatekeeper:3.21::el9"
