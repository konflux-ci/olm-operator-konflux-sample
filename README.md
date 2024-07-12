# OLM operator Konflux sample

It is possible to [build OLM operators in Konflux](https://konflux-ci.dev/docs/advanced-how-tos/building-olm/). This repository is dedicated to demonstrating how to build operators with a simple example.

In order to clearly indicate the work needed to support building the artifacts in Konflux, we will use git submodules to import sources from open source projects. This repository will only contain the build configurations needed (pipeline definitions, Containerfiles, etc.) that would be needed to build these components. If you are using this sample as a template for how to build your own artifacts, you can either follow this same pattern or integrate the build process more directly into your git repository.
