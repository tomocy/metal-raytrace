#!/bin/bash

set -e

intermediate_file_dir="${OBJROOT}/Raytrace.build/${CONFIGURATION}"
derived_source_dir="${intermediate_file_dir}/ShaderX.build/DerivedSources"

# A workaround for the targets to force to re-link this library.
rm -rf "${intermediate_file_dir}/Prelight.build/Metal"
rm -rf "${intermediate_file_dir}/Raytrace.build/Metal"

map_metal_file_to_air() {
  air_file=${1}
  air_file=${air_file//"${TARGET_SOURCE_ROOT}"/"${derived_source_dir}"}
  air_file=${air_file//.metal/.air}

  # shellcheck disable=SC2086
  echo ${air_file}
}

metal_files=$(find "${TARGET_SOURCE_ROOT}" -type f -name "*.metal")
air_files=$(map_metal_file_to_air "${metal_files}")

echo "${SCRIPT_OUTPUT_FILE_0}:"
for metal_file in ${metal_files}; do
  air_file=$(map_metal_file_to_air "${metal_file}")
  metal -c "${metal_file}" -o "${air_file}"
  echo "${metal_file} -> ${air_file}"
done

# shellcheck disable=SC2086
metal-libtool -static ${air_files} -o "${SCRIPT_OUTPUT_FILE_0}"
