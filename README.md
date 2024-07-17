# OLM operator Konflux sample

It is possible to [build OLM operators in Konflux](https://konflux-ci.dev/docs/advanced-how-tos/building-olm/). This repository is dedicated to demonstrating how to build operators with a simple example.

In order to clearly indicate the work needed to support building the artifacts in Konflux, we will use git submodules to import sources from open source projects. This repository will only contain the build configurations needed (pipeline definitions, Containerfiles, etc.) that would be needed to build these components. If you are using this sample as a template for how to build your own artifacts, you can either follow this same pattern or integrate the build process more directly into your git repository.

# Onboarding process for Konflux

In order to increase transparency into the process of onboarding, we will document the steps taken in order to enable better reproducibility.

## Prepare the git repository (optional)

If you already have a git repository created for an artifact you want to build in Konflux then you can skip this step. It is likely that this will not be the desired pattern for many projects being onboarded as the intention behind Konflux is to shift testing as far left as possible (into the project repository itself, for example). Therefore, you will likely be onboarding a repository which is currently configured for building in another system.

In this repository, we used git submodules to [pull together multiple remote references](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/1) in order to specify the build configuration in one place. You should get the code in place which builds properly locally so that the onboarding process to Konflux can be simplified.

## Onboard component(s) to Konflux

After you have your git repository, the first step that is required is to create an application and onboard your component(s). This process can be done in either the UI or using a GitOps approach. While the initial component onboarding was performed using the UI for this sample, the CRs have also been defined via [GitOps after the fact](https://github.com/redhat-appstudio/tenants-config/pull/482).

### Merge tekton pipleine definitions

Regardless of how components are onboarded, each will have their own PR for creating the PipelinesAsCode (PAC) PipelineRuns to build the artifacts. In this sample, two components were initially onboarded, [gatekeeper](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/2) and [gatekeeper-operator](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/3). The PAC definitions for gatekeeper were merged even though they were failing as a follow-up PR was planned to overhaul the PipelineDefinitions.

After onboarding the components to Konflux, a PR will be sent to the repository with the pipeline definitions. The PR can be easily merged if the build completes as specified (i.e. with the provided context and Containerfile). If the repository or the Tekton PipelineRun need to be updated to get the build to pass, you can push changes to the source branch in the repository to update the PR.

### Customize tekton pipleines

After merging the initial Tekton PipelineRuns to the repository, the structure of the `.tekton` directory [was overhauled](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/4) to make it simpler to work on the components. Some of the key changes that were made include:

* Utilization of multi-arch builds. We knew that we would need to build the container images for multiple architectures, so this pipeline was added to the repository (in the future, it will be possible to directly onboard with a multi-arch pipeline).
* Use of common in-repo Tekton PipelineDefinitions for multi-arch and single-arch builds. The PAC PipelineRuns then refer to these PipelineDefinitions. This enables the pipeline to be modified once in the repository and then all components building with that definition will be updated for pull request and push events.
* Adding appropriate `on-cel-expression`s to reduce unnecessary builds while still rebuilding if any relevant content was modified.
* Utilization of OCI [trusted artifacts](https://konflux-ci.dev/architecture/ADR/0036-trusted-artifacts.html) to remove the dependency on a PersistentVolumeClaim for the pipeline.

More information on the specifics for these customizations can be found [below](#functionality-demonstrated-in-this-repository).

NOTE: The multi-arch builds were not properly building the index image until [all architectures](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/15) were enabled.

### Add more Components as necessary

We onboarded the bundle component after the first two components were built. The process of onboarding components as well as merging and customizing the pipelines can be repeated until all components are created and building properly.

If all of your components are not building properly when you onboard new components, you may see some failures in the onboarding PR. For example, we saw a failure in the [onboarding PR](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/5) due to another component being built. That issue was being worked on in [another PR in parallel](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/4) and had not yet been merged. Another case where the PRs can indicate failure from other components is if the IntegrationTestScenarios (ITS) are reporting an error. Since the ITS is run against a snapshot of all components in an application, a failure in one (for example an enterprise contract violation) will report back on a PR for any component in the application. If you do not want to override the CI failures to merge, then you will need to ensure that the base reference is properly building before onboarding a new component.

## Maintain the pipeline task references

Konflux leverages [Enterprise Contract](https://enterprisecontract.dev/) for verifying that artifacts comply with a specific set of policies. One of the policies that can be configured ensures that the task bundle reference is the [latest version available](https://enterprisecontract.dev/docs/ec-policies/release_policy.html#attestation_task_bundle__task_ref_bundles_current). In order to ensure that this policy does not fail, task updates proposed by Konflux need to be merged within 30 days. This task data is contained in the [data-acceptable-bundles](quay.io/konflux-ci/tekton-catalog/data-acceptable-bundles:latest) OCI artifact.

## Add component nudge relationships

In order to ensure that the bundle image is always up to date with the latest gatekeeper and gatekeeper-operator images, we need to configure [component nudges](https://konflux-ci.dev/docs/how-tos/configuring/component-nudges/). First, the Components were modified [via ArgoCD](https://github.com/redhat-appstudio/tenants-config/pull/498) and then we had to configure the push pipelines to indicate which files need to have the pullspecs updated in.

We prepared for these nudges by reworking how the bundles [are built](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/16). In that PR, we ensured that we have the full pullspec (and digest) of the nudging components' images in a file. This process enables us to easily modify and update the ClusterServiceVersion in the bundle image. While it is possible to update the image pullspecs directly in the bundle as well, it was separated out here to specifically enable additional customizations on top of the `operator-sdk` tooling to build the bundle.

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

The gatekeeper and gatekeeper operator's "push" pipelines both specify the file to nudge component references in via the `build.appstudio.openshift.io/build-nudge-files` annotation. Since the location of the component references is atypical (i.e. not a Containerfile or yaml file), we need to configure this annotation.