#!/bin/bash

###########################################################################################
# This script creates test Platform Certificates which are placed in examples/.
###########################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="${SCRIPT_DIR}/config"
EXAMPLES_PATH="${SCRIPT_DIR}/../examples"
LEAF_KEY_PATH="${SCRIPT_DIR}/keys/ecc/"
EXT_FILE="Extensions.json"
POLICY_FILE="PolicyReference.json"
OUT_ROOT="${EXAMPLES_PATH}/platform_certs"
EK_CERT_PATH="${EXAMPLES_PATH}/tpm_endorsement_certs/ecc/"
OEM_LEAF_CERT_PATH="${EXAMPLES_PATH}/certificate_chains/oem/ecc/leaf/"
VAR_LEAF_CERT_PATH="${EXAMPLES_PATH}/certificate_chains/var/ecc/leaf/"
PACCOR_BIN="${PACCOR_BIN:-/opt/paccor/bin/paccor}"
DATE_NOT_BEFORE="20180101"
DATE_NOT_AFTER="20680101"

# Return file name of EK cert
ek_cert_file() {
    CURVE="$1"
    echo "${EK_CERT_PATH}TCG_EK_ecc_p${CURVE}_Test.pem"
}

# Return file name of Platform cert
plat_cert_file() {
    VERSION="$1"
    CURVE="$2"
    USE_CASE="$3"

    OUT_PATH="${OUT_ROOT}/${VERSION}/"
    FILE="TCG_PlatCert_${VERSION}_${USE_CASE}_ecc_p${CURVE}_Test.pem"

    if [[ "${USE_CASE}" == Server* ]]; then
        echo "${OUT_PATH}server/attribute/ecc/${FILE}"
    else
        echo "${OUT_PATH}pc/attribute/ecc/${FILE}"
    fi
}

# Check dependencies for existing certs, warn if not found
check_dependency() {
    VERSION="$1"
    CURVE="$2"
    DELTA_USE_CASE="$3"
    BASE_USE_CASE="$4"
    DELTA_CERT="$(plat_cert_file "${VERSION}" "${CURVE}" "${DELTA_USE_CASE}")"
    BASE_CERT="$(plat_cert_file "${VERSION}" "${CURVE}" "${BASE_USE_CASE}")"

    if [ -f "${DELTA_CERT}" ] && [ ! -f "${BASE_CERT}" ]; then
        echo "WARNING: Platform Credential ${VERSION} ECC${CURVE}/${BASE_USE_CASE} is missing but a certificate that depends on it exists:"
        echo "       ${DELTA_CERT}"
        echo "       If the Base Platform Certificate is regenerated, you may also need to regenerate the Delta Platform Certificate. See /scripts/README.md for more details."
    fi
}

for version in v1.1; do
    for curve in 256 384 521; do
        check_dependency "${version}" "${curve}" "PCUseCase2" "PCUseCase1"
        check_dependency "${version}" "${curve}" "ServerUseCase2" "ServerBareBones"
    done
done

TMP_ROOT="$(mktemp -d "${EXAMPLES_PATH}/.tmp_XXXXXX")"
TMP_TBS_PATH="${TMP_ROOT}/tbs/"
mkdir -p "${TMP_TBS_PATH}"

# Clean up temp directory upon any exit
cleanup() {
    rm -rf "${TMP_ROOT}"
    echo ""
    echo "${TMP_ROOT} deleted"
    echo ""
}
trap cleanup EXIT

# Function to create and validate 1 platform certificate
create_plat_cert() {
    VERSION="$1"
    CURVE="$2"
    SN="$3"
    HOLDER="$4"
    USE_CASE="$5"
    PS="$6"
    PLAT_CERT="$7"

    CONFIG_PATH="${CONFIG_ROOT}/platform_certs_${VERSION}/"
    OUT_PATH="${OUT_ROOT}/${VERSION}/"

    LEAF_CERT_PATH="${OEM_LEAF_CERT_PATH}"
    LEAF_KEY="TCG_OEM_ecc_p${CURVE}_TestCA_Leaf.key"
    LEAF_CERT="TCG_OEM_ecc_p${CURVE}_TestCA_Leaf.pem"
    CONFIG_FILE="ComponentList_${USE_CASE}.json"
    OUT_FILE="TCG_PlatCert_${VERSION}_${USE_CASE}_ecc_p${CURVE}_Test.pem"

    if [[ "${USE_CASE}" == Server* ]]; then
        FULL_OUT_PATH="${OUT_PATH}server/attribute/ecc/${OUT_FILE}"
    else
        FULL_OUT_PATH="${OUT_PATH}pc/attribute/ecc/${OUT_FILE}"
    fi

    # Skip generation if cert already exists
    if [ -f "${FULL_OUT_PATH}" ]; then
        echo "${FULL_OUT_PATH} already exists, skipping."
        return 0
    fi

    # Use VAR leaf instead of OEM if applicable
    if [ "${PLAT_CERT}" = "var" ]; then
        LEAF_CERT_PATH="${VAR_LEAF_CERT_PATH}"
        LEAF_KEY="TCG_VAR_ecc_p${CURVE}_TestCA_Leaf.key"
        LEAF_CERT="TCG_VAR_ecc_p${CURVE}_TestCA_Leaf.pem"
    fi

    CERT_TYPE="base"
    if [ "${USE_CASE}" = "PCUseCase2" ] || [ "${USE_CASE}" = "ServerUseCase2" ]; then
        CERT_TYPE="delta"
    fi

    # Set Platform Serial Number in config file
    set_platform_serial() {
        TARGET_FILE="$1"
        TMP_CONFIG="$(mktemp)"

        jq --arg ps "${PS}" \
            '.PLATFORM.PLATFORMSERIAL = ("Sample Platform Serial " + $ps)' \
            "${TARGET_FILE}" > "${TMP_CONFIG}" || {
            echo "Failed to set PLATFORMSERIAL in ${TARGET_FILE}"
            rm -f "${TMP_CONFIG}"
            exit 1
        }

        mv "${TMP_CONFIG}" "${TARGET_FILE}"
    }
    set_platform_serial "${CONFIG_PATH}${CONFIG_FILE}"
    if [ "${CERT_TYPE}" = "delta" ]; then
        set_platform_serial \
            "${CONFIG_PATH}ComponentList_${USE_CASE}_FinalState.json"
    fi

    TBS_FILE="${TMP_TBS_PATH}TCG_PlatCert_${VERSION}_${USE_CASE}_ecc_p${CURVE}_Test.tbs.json"

    echo "Creating Platform Certificate ${VERSION} using ECC Length ${CURVE} for ${USE_CASE}..."
    if ! "${PACCOR_BIN}" certgen \
        -x "${CONFIG_PATH}${EXT_FILE}" \
        -c "${CONFIG_PATH}${CONFIG_FILE}" \
        -e "${HOLDER}" \
        -p "${CONFIG_PATH}${POLICY_FILE}" \
        -P "${LEAF_CERT_PATH}${LEAF_CERT}" \
        -N "${SN}" \
        -b "${DATE_NOT_BEFORE}" \
        -a "${DATE_NOT_AFTER}" \
        -f "${TBS_FILE}" \
        --type "${CERT_TYPE}" \
        --finalize; then
        echo "The Platform Certificate data could not be gathered, exiting."
        exit 1
    fi

    if ! "${PACCOR_BIN}" assemble \
        --in "${TBS_FILE}" \
        -k "${LEAF_KEY_PATH}${LEAF_KEY}" \
        -P "${LEAF_CERT_PATH}${LEAF_CERT}" \
        --pem \
        -f "${FULL_OUT_PATH}"; then
        echo "The Platform Certificate could not be signed, exiting."
        rm -f "${TBS_FILE}"
        exit 1
    fi

    # Determine Delta cert args for validation
    PREV_PCERT_ARG=()
    if [ "${USE_CASE}" = "PCUseCase2" ]; then
        PREV_PCERT_ARG=(
            --prev-pcert "$(plat_cert_file "${VERSION}" "${CURVE}" "PCUseCase1")"
        )
    elif [ "${USE_CASE}" = "ServerUseCase2" ]; then
        PREV_PCERT_ARG=(
            --prev-pcert "$(plat_cert_file "${VERSION}" "${CURVE}" "ServerBareBones")"
        )
    fi

    VALIDATION_CONFIG_FILE="${CONFIG_FILE}"
    if [ "${USE_CASE}" = "PCUseCase2" ] || [ "${USE_CASE}" = "ServerUseCase2" ]; then
        VALIDATION_CONFIG_FILE="ComponentList_${USE_CASE}_FinalState.json"
    fi

    # Platform Cert validation with PACCOR validate
    if "${PACCOR_BIN}" validate \
        -P "${LEAF_CERT_PATH}${LEAF_CERT}" \
        -X "${FULL_OUT_PATH}" \
        -c "${CONFIG_PATH}${VALIDATION_CONFIG_FILE}" \
        "${PREV_PCERT_ARG[@]}"; then
        echo "Platform Credential ${VERSION} for ECC${CURVE}/${USE_CASE} has been created and validated as ${OUT_FILE}."
    else
        rm -f "${FULL_OUT_PATH}"
        echo "Validation failed for Platform Credential ${VERSION}: ECC${CURVE}/${USE_CASE}."
    fi
}

# Create Platform Certs: 3 ECC lengths per Use Case
create_plat_cert "v1.1" "256" 20 "$(ek_cert_file "256")" "PCBareBones" 1 "oem"
create_plat_cert "v1.1" "384" 21 "$(ek_cert_file "384")" "PCBareBones" 2 "oem"
create_plat_cert "v1.1" "521" 22 "$(ek_cert_file "521")" "PCBareBones" 3 "oem"
create_plat_cert "v1.1" "256" 23 "$(ek_cert_file "256")" "PCUseCase1" 4 "oem"
create_plat_cert "v1.1" "384" 24 "$(ek_cert_file "384")" "PCUseCase1" 5 "oem"
create_plat_cert "v1.1" "521" 25 "$(ek_cert_file "521")" "PCUseCase1" 6 "oem"
create_plat_cert "v1.1" "256" 26 "$(plat_cert_file "v1.1" "256" "PCUseCase1")" "PCUseCase2" 4 "var"
create_plat_cert "v1.1" "384" 27 "$(plat_cert_file "v1.1" "384" "PCUseCase1")" "PCUseCase2" 5 "var"
create_plat_cert "v1.1" "521" 28 "$(plat_cert_file "v1.1" "521" "PCUseCase1")" "PCUseCase2" 6 "var"
create_plat_cert "v1.1" "256" 29 "$(ek_cert_file "256")" "ServerBareBones" 7 "oem"
create_plat_cert "v1.1" "384" 30 "$(ek_cert_file "384")" "ServerBareBones" 8 "oem"
create_plat_cert "v1.1" "521" 31 "$(ek_cert_file "521")" "ServerBareBones" 9 "oem"
create_plat_cert "v1.1" "256" 32 "$(ek_cert_file "256")" "ServerUseCase1" 10 "oem"
create_plat_cert "v1.1" "384" 33 "$(ek_cert_file "384")" "ServerUseCase1" 11 "oem"
create_plat_cert "v1.1" "521" 34 "$(ek_cert_file "521")" "ServerUseCase1" 12 "oem"
create_plat_cert "v1.1" "256" 35 "$(plat_cert_file "v1.1" "256" "ServerBareBones")" "ServerUseCase2" 7 "var"
create_plat_cert "v1.1" "384" 36 "$(plat_cert_file "v1.1" "384" "ServerBareBones")" "ServerUseCase2" 8 "var"
create_plat_cert "v1.1" "521" 37 "$(plat_cert_file "v1.1" "521" "ServerBareBones")" "ServerUseCase2" 9 "var"

echo ""
echo "All certificates generated."
