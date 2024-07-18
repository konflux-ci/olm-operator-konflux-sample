# Functionality demonstrated in this repository

While it is possible to limit the konflux-sample repositories to only illustrate a specific functionality or tip, many different changes are leveraged in this repository in order to improve the comprehension and maintenance of the repository. The key customizations and changes made are:

## Using a pipelineRef to unify on a common PipelineDefinition

By default, Konflux will push two Tekton PipelineRun files for PAC to trigger on the cluster. Since these files share a large part of common specification, maintenance and customization can become harder especially if there are multiple artifacts being built in a repository with effectively the same repository.

There are two common pipelines defined in this repository, [single-arch-build-pipeline](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/main/.tekton/single-arch-build-pipeline.yaml) and [multi-arch-build-pipeline](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/main/.tekton/multi-arch-build-pipeline.yaml). Each of the PipelineRuns that are used by PAC then refer to one of the pipeline definitions with a `pipelineRef`, for example

```yaml
  pipelineRef:
    name: multi-arch-build-pipeline
```

## Building artifacts on multiple platforms

Tekton Pipelines are a collection of Tasks which run in pods in the cluster. The default Tekton PipelineRun that is pushed to repositories only build images for a single architecture -- the cluster's. This results in image artifacts only being built and pushed to the registry as an [Image Manifest](https://github.com/opencontainers/image-spec/blob/main/manifest.md) with the default `docker-build` pipeline. These images produced do _not_ have an [Image Index](https://github.com/opencontainers/image-spec/blob/main/image-index.md) produced which enable the container execution environment to pull an image which matches the running system.

Since it is not currently possible to build on multiple architectures natively from within Tekton, a [custom controller](https://github.com/konflux-ci/architecture/blob/main/architecture/multi-platform-controller.md) was developed for native building on multiple platforms in Konflux.

The pipeline definition supporting these builds in this repository is [multi-arch-build-pipeline](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/main/.tekton/multi-arch-build-pipeline.yaml) (in the future, a multi-platform pipeline will be available at onboard time). Remote build tasks can be triggered on any remote virtual machines that are configured via the `PLATFORM` parameter. A remote build is triggered for each specific architecture (for example, [amd64](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/b6e2be4885cb4d778804c016f953671d24f91627/.tekton/multi-arch-build-pipeline.yaml#L76-L119)) and then an OCI Image Index is [generated](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/b6e2be4885cb4d778804c016f953671d24f91627/.tekton/multi-arch-build-pipeline.yaml#L252-L282) referencing each of the architecture-specific Image Manifests.

~Since we have a single PipelineDefinition for multiple component builds, some customization may be desired [on a component level](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/b6e2be4885cb4d778804c016f953671d24f91627/.tekton/gatekeeper-push.yaml#L31-L40). In order to support this, parameters are [added to the definition](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/b6e2be4885cb4d778804c016f953671d24f91627/.tekton/multi-arch-build-pipeline.yaml#L512-L543) to allow specific architectures to be run as well as modifying the platform used (in case there a larger size is needed for a build).~

EDIT: The original approach does not fully work as anticipated. While the common pipeline can be used, the parameters to enable the multi-arch builds are not sufficient to build on a subset of architectures. If all architectures are not produced, the `values` to the `build-image-index` cannot contain references to results from these skipped tasks. If skipped tasks are referenced, the Image Index generation will also be skipped. Use of [matrix builds](https://issues.redhat.com/browse/EC-654) will improve the situation. This sample will be updated once the functionality is supported.

<!-- TODO: switch out https://github.com/konflux-ci/architecture/blob/main/architecture/multi-platform-controller.md for an ADR -->

## Trusted artifacts, removing the need for PVCs

The initial onboarding PRs from Konflux proposed a Tekton Pipeline that utilized PersistentVolumeClaims (PVC) for a shared workspace between tasks (see [gatekeeper-operator](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/3/files#diff-2974de75bb3cd70a435862ea12163c937433c19c533776a595117c9d02bcb1dfR440-R450), for an example). While these pipelines work for building artifacts, there are a couple primary limitations to the approach:

* PVCs often have a quota within a workspace due to the infrastructure backing them. Removing a restriction on the PVC quotas increases the number of PipelineRuns that can progress in parallel.
* All TaskRuns utilizing a shared PVC-backed workspace need to be run on the same node. This prevent k8s from scheduling each TaskRun from being able to effectively distribute workloads, especially when those workloads are long-running pipelines.
* When content is shared in a PVC between tasks, the only way to ensure that the data hasn't been tampered with is to prevent any custom tasks that might access the workspace. This means that if users want to continue to pass Enterprise Contract policy verifications that they would be unable to add additional custom tasks to the pipeline like running unit tests on the repository or built artifacts.

Since data still needs to be shared between tasks, however, an alternative to PVCs are needed. Konflux enables pipelines to be able to leverage OCI-backed [trusted artifacts](https://konflux-ci.dev/architecture/ADR/0036-trusted-artifacts.html). Instead of storing data in a PVC, tasks in Konflux can leverage the [trusted artifact image](https://github.com/konflux-ci/build-trusted-artifacts) to use and create OCI images to pass data between tasks. Since the digest of these images are recorded in the generated provenance, we can then verify the integrity of the data's chain of custody.

## Utilization of `on-cel-expressions` for reducing redundant builds

After properly configuring the cel expressions, a PR which updates content that only affects a single component (for example, the [only single-arch component](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/8)) should not trigger builds for the rest of the components. This can be achieved by modifying the default `on-cel-expressions` to include filtering events based on the files changed. For example, the [expressions](https://github.com/konflux-ci/olm-operator-konflux-sample/blob/7af3b0636b9229965a3353abb6d70e2a7c53a4e2/.tekton/gatekeeper-operator-bundle-pull-request.yaml#L10-L15) for `gatekeeper-operator-bundle` which was built above is:

```yaml
    pipelinesascode.tekton.dev/on-cel-expression: event == "pull_request" && target_branch == "main" && 
      (".tekton/single-arch-build-pipeline.yaml".pathChanged() || 
      ".tekton/gatekeeper-operator-bundle-pull-request.yaml".pathChanged() || 
      ".tekton/gatekeeper-operator-bundle-push.yaml".pathChanged() || 
      "Containerfile.gatekeeper-operator-bundle".pathChanged() ||
      "gatekeeper-operator".pathChanged())
```

This indicates that the PipelineRun will only be executed if the event is a PR to the main branch and if on of the 5 specified files were included in the changeset. Documentation for filtering events can be found in [Pipelines as Code](https://pipelinesascode.com/docs/guide/authoringprs/#advanced-event-matching).

While this results in improved resource utilization (lower cloud spend), it does mean that not all artifacts will be built from every commit. If you need to identify the specific commit which produced an artifact, you can query the artifact's attestations for the [build parameters](https://konflux-ci.dev/docs/how-tos/metadata/attestations/#identify-the-build-parameters).

## Customization of files for component nudging

The gatekeeper and gatekeeper operator's "push" pipelines both specify the file to nudge component references in via the `build.appstudio.openshift.io/build-nudge-files` annotation. Since the location of the component references is atypical (i.e. not a Containerfile or yaml file), we need to configure this annotation. Once this annotation is set, the newly built operand and operator images will trigger a pull request against the `update_bundle.sh` file (i.e. konflux-ci/olm-operator-konflux-sample#21 and konflux-ci/olm-operator-konflux-sample#22).