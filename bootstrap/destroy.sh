#!/usr/bin/env bash

echo "Destroying Kind cluster 'kind'..."
kind delete cluster --name kind

echo "Cleanup complete."
