## Building a File-Based Catalog from catalog template

The `fbc-builder` pipeline in Konflux now allows you to generate the `catalog.json` file directly,  
simplifying the process of creating a file-based catalog.  
The `run-opm-command` task uses the `opm` command to build the catalog from the `catalog-template.yaml`.

### Generating the `catalog.json` with the `fbc-builder` Pipeline

To generate the `catalog.json` file, you need to run the `fbc-builder` pipeline.  
For the `run-opm-command` task, you must set the following parameters: `OPM_ARGS`, `OPM_OUTPUT_PATH`, and `IDMS_PATH`.

**Example:**
```yaml
- name: OPM_ARGS
  value:
    - alpha
    - render-template
    - basic
    - "v4.13/catalog-template.json"
- name: OPM_OUTPUT_PATH
  value: "v4.13/catalog/gatekeeper-operator/catalog.json"
- name: IDMS_PATH
  value: ".tekton/images-mirror-set.yaml"
- name: FILE_TO_UPDATE_PULLSPEC
  value: "v4.13/catalog-template.json"
```

Note: For OCP version >= v4.17 you have to add `--migrate-level=bundle-object-to-csv-metadata` as well.  
Example for OCP >= v4.17: 
```yaml
- name: OPM_ARGS
  value:
    - alpha
    - render-template
    - basic
    - "v4.18/catalog-template.json"
    - "--migrate-level=bundle-object-to-csv-metadata"
- name: OPM_OUTPUT_PATH
  value: "v4.18/catalog/gatekeeper-operator/catalog.json"
- name: IDMS_PATH
  value: ".tekton/images-mirror-set.yaml"
- name: FILE_TO_UPDATE_PULLSPEC
  value: "v4.18/catalog-template.json"
```

**Description of variables:**

- `OPM_ARGS`: An array of arguments passed to `opm` when executed.
- `OPM_OUTPUT_PATH`: The path where the output from `opm` will be stored (i.e., where `catalog.json` will be saved).
  - Note: This task supports only the JSON format for catalog generation.
- `IDMS_PATH`: The path to the ImageDigestMirrorSet file in YAML format.
- `FILE_TO_UPDATE_PULLSPEC`: Relative path to a file (e.g., catalog-template.yml) in which pullspecs should be updated.

Examples of complete `fbc-builder` pipeline configurations can be found in [PR#132](https://github.com/konflux-ci/olm-operator-konflux-sample/pull/132):

- [gatekeeper-fbc-v413-push.yaml](../.tekton/gatekeeper-fbc-v413-push.yaml)  
- [gatekeeper-fbc-v413-pull-request.yaml](../.tekton/gatekeeper-fbc-v413-pull-request.yaml)

Once the pipeline has completed successfully, the `catalog.json` file will be available in the source artifact of the pipeline run.

This new process eliminates the need to manually run the `opm` command on your local machine and to manage the resulting `catalog.json` file in your Git repository.
