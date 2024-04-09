#!/bin/bash

set -e

metal_files=$(find "${TARGET_SOURCE_ROOT}" -type f -name "*.metal")

target="${TARGET_SOURCE_ROOT}/Source.xcfilelist"
echo "${target}:"
: > "${target}"
for file in ${metal_files}; do
  echo "- ${file}"
  echo "${file}" >> "${target}"
done
