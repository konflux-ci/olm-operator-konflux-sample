# OLM operator Konflux sample

It is possible to [build Operator Lifecyle Manager (OLM) operators in Konflux](https://konflux-ci.dev/docs/advanced-how-tos/building-olm/). This repository is dedicated to demonstrating how to build operators with a simple example.

## Build sources

In order to clearly indicate the work needed to support building the artifacts in Konflux, we will use git submodules to import the sources from other open source projects as the base for the artifacts built. This repository will only contain the build configurations needed (pipeline definitions, Containerfiles, scripts, etc.) that might be needed to build these components. If you are using this sample as a template for how to build your own artifacts, you can either follow this same pattern or integrate the build process more directly into your git repository.

## Konflux onboarding process

Building OLM operators involves many different components that are inter-connected. While each aspect of the operators can be built within Konflux, care needs to be taken to ensure that the components are onboarded in an appropriate order and that they are properly referencing each other. We will aim to clearly describe this process in the [onboarding docs](docs/konflux-onboarding.md).

## Functionality demonstrated

Konflux offers many different features and functionality. While this sample will not explore all of the features, there are many different techniques that will be demonstrated. We will aim to clearly describe these in [demonstrated functionality docs](docs/functionality-demonstrated.md).
