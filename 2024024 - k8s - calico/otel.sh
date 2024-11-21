#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Open Telemetry Demo"
whoami
pwd

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install otel-demo open-telemetry/opentelemetry-demo --create-namespace --namespace otel-demo --wait --timeout 10m
echo "Finished Open Telemetry Demo"
