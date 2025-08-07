#!/bin/bash

script_dir=$(dirname -- ${BASH_SOURCE[0]})


sudo docker build --build-arg REPO_LOCATION= --build-arg PROXY=none  -f $script_dir/Dockerfile_GPU -t ti_rtos_base .
