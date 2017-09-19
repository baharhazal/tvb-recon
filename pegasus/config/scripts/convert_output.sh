#!/usr/bin/env bash

source ${ANACONDA_ACTIVATE} ${PYTHON3_ENVIRONMENT}

export FREESURFER_HOME
export SUBJECTS_DIR
source ${FREESURFER_HOME}/FreeSurferEnv.sh

python -m tvb.recon.qc.tvb_output -p $PWD $1 $2 $3 $PWD