## Building a File-Based Catalog from catalog template

The `fbc-builder` pipeline in Konflux now allows you to generate the `catalog.json` file directly,  
simplifying the process of creating a file-based catalog.  
The `run-opm-command` task uses the `opm` command to build the catalog from the `catalog-template.yaml`.

This sample builds a catalog for the `gatekeeper-operator-product` package that contains the
operator bundle produced by this repository, targeting **OCP v4.22**.

### Generating the `catalog.json` with the `fbc-builder` Pipeline

To generate the `catalog.json` file, you need to run the `fbc-builder` pipeline.  
For the `run-opm-command` task, you must set the following parameters: `OPM_ARGS`, `OPM_OUTPUT_PATH`, and `IDMS_PATH`.

**Example (as used by this sample for OCP v4.22):**
```yaml
- name: OPM_ARGS
  value:
    - alpha
    - render-template
    - basic
    - "--migrate-level=bundle-object-to-csv-metadata"
    - "v4.22/catalog-template.yaml"
- name: OPM_OUTPUT_PATH
  value: "v4.22/catalog/gatekeeper-operator-product/catalog.json"
- name: IDMS_PATH
  value: ".tekton/images-mirror-set.yaml"
- name: FILE_TO_UPDATE_PULLSPEC
  value: "v4.22/catalog/gatekeeper-operator-product/catalog.json"
```

Note: `--migrate-level=bundle-object-to-csv-metadata` is required for OCP version >= v4.17.
Omit it when targeting an older OCP release.

You can also parameterize the extra arguments. First, declare a parameter under `spec.params`:
```yaml
  params:
    name: opm-args
    description: Additional OPM arguments (e.g., ["--migrate-level=bundle-object-to-csv-metadata"] for v4.17+)
    type: array
    default: []
```

This parameter can then be used in `OPM_ARGS` as follows:
```yaml
- name: OPM_ARGS
  value:
  - alpha
  - render-template
  - basic
  - catalog/$(params.catalog).yaml
  - $(params.opm-args[*])
```

**Description of variables:**

- `OPM_ARGS`: An array of arguments passed to `opm` when executed.
- `OPM_OUTPUT_PATH`: The path where the output from `opm` will be stored (i.e., where `catalog.json` will be saved).
  - Note: This task supports only the JSON format for catalog generation.
- `IDMS_PATH`: The path to the ImageDigestMirrorSet file in YAML format.
- `FILE_TO_UPDATE_PULLSPEC`: Relative path to a file (e.g., `catalog.json`) in which pullspecs should be updated.

Complete `fbc-builder` pipeline configurations for this sample:

- [gatekeeper-fbc-v422-push.yaml](../.tekton/gatekeeper-fbc-v422-push.yaml)
- [gatekeeper-fbc-v422-pull-request.yaml](../.tekton/gatekeeper-fbc-v422-pull-request.yaml)

Once the pipeline has completed successfully, the `catalog.json` file will be available in the source artifact of the pipeline run.

This process eliminates the need to manually run the `opm` command on your local machine and to manage the resulting `catalog.json` file in your Git repository.

### Keeping the catalog's bundle reference current

The catalog template ([v4.22/catalog-template.yaml](../v4.22/catalog-template.yaml)) references this
sample's own `gatekeeper-operator-bundle` image by digest. A Konflux component nudge from the
`gatekeeper-operator-bundle` component to the `gatekeeper-fbc-v422` component keeps that digest
up to date whenever a new bundle is built, so you do not have to edit the digest by hand.
