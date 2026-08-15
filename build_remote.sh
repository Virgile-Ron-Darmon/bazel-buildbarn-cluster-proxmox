#!/usr/bin/env bash
# Runs the load-test build against the Buildbarn RBE cluster instead of
# locally. build.sh never set --remote_executor, so it only ever exercised
# the local machine.
#
# MASTER_IP should be the rbe_master node's static IP (10.50.0.1 by
# default -- see terraform_rbe/ansible/group_vars/rbe_master.yml).
# SCHEDULER_PORT must match scheduler_grpc_port in that same file.

set -euo pipefail

MASTER_IP="${MASTER_IP:-10.50.0.1}"
SCHEDULER_PORT="${SCHEDULER_PORT:-8982}"
JOBS="${JOBS:-100}"

bazel clean --expunge

bazel build //... \
  --jobs="${JOBS}" \
  --remote_executor="grpc://${MASTER_IP}:${SCHEDULER_PORT}" \
  --remote_default_exec_properties="OSFamily=linux" \
  --spawn_strategy=remote \
  --remote_upload_local_results=true
