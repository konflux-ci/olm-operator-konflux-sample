#!/usr/bin/env bash

export GATEKEEPER_GATEKEEPER_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/konflux-samples-tenant/olm-operator/gatekeeper@sha256:4632bc387e54960ce0bb0fdb4fdda89dbc8c7afc16c2427ff6e517fb47379256"

export GATEKEEPER_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/konflux-samples-tenant/olm-operator/gatekeeper-operator@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"

export CSV_FILE=/manifests/gatekeeper-operator.clusterserviceversion.yaml

sed -i -e "s|quay.io/gatekeeper/gatekeeper:v.*|\"${GATEKEEPER_GATEKEEPER_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/gatekeeper/gatekeeper-operator:v.*|\"${GATEKEEPER_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

export AMD64_BUILT=$(skopeo inspect --raw docker://${GATEKEEPER_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${GATEKEEPER_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${GATEKEEPER_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${GATEKEEPER_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
gatekeeper_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch support labels
gatekeeper_csv['metadata']['labels'] = gatekeeper_csv['metadata'].get('labels', {})
if os.getenv('AMD64_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
gatekeeper_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
gatekeeper_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
gatekeeper_csv['metadata']['annotations']['repository'] = 'https://github.com/stolostron/gatekeeper-operator'
gatekeeper_csv['metadata']['annotations']['containerImage'] = os.getenv('GATEKEEPER_OPERATOR_IMAGE_PULLSPEC', '')

dump_manifest(os.getenv('CSV_FILE'), gatekeeper_csv)
CSV_UPDATE

cat $CSV_FILE