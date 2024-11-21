#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Open Telemetry"
whoami
pwd

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install my-otel-demo open-telemetry/opentelemetry-demo
