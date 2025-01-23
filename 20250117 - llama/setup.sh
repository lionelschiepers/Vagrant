#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Setting up"
whoami
pwd

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl net-tools gnupg lsb-release

sudo apt-get install -y python3 python3-pip
pip install llama-stack
./bin/llama model list

./bin/llama model download --source meta --model-id Llama3.1-405B
./bin/llama model download --source meta --model-id Llama3.3-70B-Instruct
