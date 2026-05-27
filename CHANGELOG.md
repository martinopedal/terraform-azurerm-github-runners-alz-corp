# Changelog

## 1.1.0

- Added `runner_labels` input to inject custom labels as the `RUNNER_LABELS` environment variable (comma-joined).
- Backward-compatible: default empty list omits the env var, preserving v1.0.x default label behavior.

## 1.0.0

- Prepared the ALZ Corp ACA runner module for first stable registry release.
- Confirmed the module has the standard Terraform module files, examples, CI validation, MIT license, and generated terraform-docs README content.
- Renamed the Terraform requirements file to `versions.tf` to match the standard module layout.