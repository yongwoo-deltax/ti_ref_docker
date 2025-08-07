#!/bin/bash

script_dir=$(dirname -- ${BASH_SOURCE[0]})


sudo docker build --build-arg REPO_LOCATION= --build-arg PROXY=none  -f $script_dir/Dockerfile_GPU_root_only -t ti_rtos_base_root .
