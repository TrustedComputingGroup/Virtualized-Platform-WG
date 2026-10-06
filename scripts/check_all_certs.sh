#!/bin/bash
####################################################################################
# Checks signatures on all example certificates.
####################################################################################

ERROR_COUNT=0
TEST_COUNT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_PATH="${SCRIPT_DIR}/../examples"
CONFIG_PATH="${SCRIPT_DIR}/config/platform_certs_v1.1/"
PACCOR_BIN="${PACCOR_BIN:-/opt/paccor/bin/paccor}"

# Checks the signature on a specific certificate chain (Root and Leaf certs)
check_cert_chain() {
    local ALG="$1"
    local ACTOR="$2"
    local ALG_SHORT

    if [[ "${ALG}" == *"ecc"* ]]; then
        ALG_SHORT="ecc"
    else
        echo "ERROR: Unsupported algorithm: ${ALG}" >&2
        return 1
    fi

    ROOT_NAME="TCG_${ACTOR}_${ALG}_TestRootCA"
    LEAF_NAME="TCG_${ACTOR}_${ALG}_TestCA_Leaf"
    ROOT_PATH="${EXAMPLES_PATH}/certificate_chains/${ACTOR,,}/${ALG_SHORT}/root/"
    LEAF_PATH="${EXAMPLES_PATH}/certificate_chains/${ACTOR,,}/${ALG_SHORT}/leaf/"
    CA_ROOT_CERT="${ROOT_PATH}${ROOT_NAME}.pem"
    LEAF_CERT="${LEAF_PATH}${LEAF_NAME}.pem"

    # Check Root
    if ! openssl verify -CAfile "${CA_ROOT_CERT}" "${CA_ROOT_CERT}"; then
        ((ERROR_COUNT++))
    fi
    ((TEST_COUNT++))
    # Check Leaves
    if ! openssl verify -CAfile "${CA_ROOT_CERT}" "${LEAF_CERT}"; then
        ((ERROR_COUNT++))
    fi
    ((TEST_COUNT++))
}

# Checks the signature on a single EK Cert
check_ek_cert() {
    local ALG="$1"
    local ACTOR="TPM"
    local ALG_SHORT

    if [[ "${ALG}" == *"ecc"* ]]; then
        ALG_SHORT="ecc"
    else
        echo "ERROR: Unsupported algorithm: ${ALG}" >&2
        return 1
    fi

    EK_NAME="TCG_EK_${ALG}_Test"
    CHAIN_NAME="TCG_${ACTOR}_${ALG}_Test_CertChain"
    EK_CERT_PATH="${EXAMPLES_PATH}/tpm_endorsement_certs/${ALG_SHORT}/"
    CHAIN_PATH="${EXAMPLES_PATH}/certificate_chains/${ACTOR,,}/${ALG_SHORT}/chain/"

    if ! openssl verify -CAfile "${CHAIN_PATH}${CHAIN_NAME}.pem" "${EK_CERT_PATH}${EK_NAME}.pem"; then
        ((ERROR_COUNT++))
    fi
    ((TEST_COUNT++))
}

# Checks the signature on a specific platform cert
check_plat_cert() {
    ISSUER_CERT_PATH="$1"
    ISSUER_CERT_FILE="$2"
    CERT_PATH="$3"
    CERT_FILE="$4"
    CONFIG_FILE="$5"
    PLATFORM_SERIAL="$6"
    shift 6

    ISSUER_FILE="${ISSUER_CERT_PATH}${ISSUER_CERT_FILE}"
    CERT_TO_VALIDATE="${CERT_PATH}${CERT_FILE}"

    if [ ! -f "${CERT_TO_VALIDATE}" ]; then
        echo "Platform Cert ${CERT_TO_VALIDATE} does not exist"
        ((ERROR_COUNT++))
    else
        TMP_CONFIG="$(mktemp)"

        jq --arg ps "${PLATFORM_SERIAL}" \
            '.PLATFORM.PLATFORMSERIAL = ("Sample Platform Serial " + $ps)' \
            "${CONFIG_PATH}${CONFIG_FILE}" > "${TMP_CONFIG}" || {
            echo "Failed to create temporary validation config for ${CERT_FILE}"
            rm -f "${TMP_CONFIG}"
            ((ERROR_COUNT++))
            ((TEST_COUNT++))
            return
        }

        if "${PACCOR_BIN}" validate \
            -P "${ISSUER_FILE}" \
            -X "${CERT_TO_VALIDATE}" \
            -c "${TMP_CONFIG}" \
            "$@"; then
            echo "    PASS: Validation of ${CERT_FILE} passed using ${ISSUER_CERT_FILE}"
        else
            ((ERROR_COUNT++))
            echo "    FAIL: *** Error **** Validation of ${CERT_TO_VALIDATE} failed"
        fi

        rm -f "${TMP_CONFIG}"
    fi

    ((TEST_COUNT++))
}

check_plat_certs() {
    local ALG="$1"
    local PLATFORM_CLASS="$2"
    local PC_VERSION="v1.1"
    local ALG_SHORT
    local BAREBONES_PS
    local USECASE1_PS
    local USECASE2_PS

    if [[ "${ALG}" == *"ecc"* ]]; then
        ALG_SHORT="ecc"
    else
        echo "ERROR: Unsupported algorithm: ${ALG}" >&2
        return 1
    fi

    PLAT_CERT_PATH="${EXAMPLES_PATH}/platform_certs/v1.1/${PLATFORM_CLASS,,}/attribute/${ALG_SHORT}/"
    OEM_ISSUER_PATH="${EXAMPLES_PATH}/certificate_chains/oem/${ALG_SHORT}/leaf/"
    VAR_ISSUER_PATH="${EXAMPLES_PATH}/certificate_chains/var/${ALG_SHORT}/leaf/"
    OEM_ISSUER_FILE="TCG_OEM_${ALG}_TestCA_Leaf.pem"
    VAR_ISSUER_FILE="TCG_VAR_${ALG}_TestCA_Leaf.pem"

    if [ ! -x "${PACCOR_BIN}" ]; then
        echo "ERROR: PACCOR executable not found or not executable: ${PACCOR_BIN}" >&2
        return 1
    fi

    USE_CASE_BARE_BONES="${PLATFORM_CLASS}BareBones"
    USE_CASE_1="${PLATFORM_CLASS}UseCase1"
    USE_CASE_2="${PLATFORM_CLASS}UseCase2"

    # Determine expected Platform Serial Numbers for this curve/platform class
    case "${ALG}" in
        ecc_p256)
            if [ "${PLATFORM_CLASS}" = "PC" ]; then
                BAREBONES_PS=1
                USECASE1_PS=4
                USECASE2_PS=4
            else
                BAREBONES_PS=7
                USECASE1_PS=10
                USECASE2_PS=7
            fi
            ;;
        ecc_p384)
            if [ "${PLATFORM_CLASS}" = "PC" ]; then
                BAREBONES_PS=2
                USECASE1_PS=5
                USECASE2_PS=5
            else
                BAREBONES_PS=8
                USECASE1_PS=11
                USECASE2_PS=8
            fi
            ;;
        ecc_p521)
            if [ "${PLATFORM_CLASS}" = "PC" ]; then
                BAREBONES_PS=3
                USECASE1_PS=6
                USECASE2_PS=6
            else
                BAREBONES_PS=9
                USECASE1_PS=12
                USECASE2_PS=9
            fi
            ;;
    esac

    # Bare Bones
    PLAT_CERT_FILE="TCG_PlatCert_${PC_VERSION}_${USE_CASE_BARE_BONES}_${ALG}_Test.pem"
    CONFIG_FILE="ComponentList_${USE_CASE_BARE_BONES}.json"

    check_plat_cert \
        "${OEM_ISSUER_PATH}" \
        "${OEM_ISSUER_FILE}" \
        "${PLAT_CERT_PATH}" \
        "${PLAT_CERT_FILE}" \
        "${CONFIG_FILE}" \
        "${BAREBONES_PS}"

    # Use Case 1
    PLAT_CERT_FILE="TCG_PlatCert_${PC_VERSION}_${USE_CASE_1}_${ALG}_Test.pem"
    CONFIG_FILE="ComponentList_${USE_CASE_1}.json"

    check_plat_cert \
        "${OEM_ISSUER_PATH}" \
        "${OEM_ISSUER_FILE}" \
        "${PLAT_CERT_PATH}" \
        "${PLAT_CERT_FILE}" \
        "${CONFIG_FILE}" \
        "${USECASE1_PS}"

    # Use Case 2
    PLAT_CERT_FILE="TCG_PlatCert_${PC_VERSION}_${USE_CASE_2}_${ALG}_Test.pem"
    CONFIG_FILE="ComponentList_${USE_CASE_2}_FinalState.json"

    if [ "${PLATFORM_CLASS}" = "PC" ]; then
        PREV_PCERT="${PLAT_CERT_PATH}TCG_PlatCert_${PC_VERSION}_PCUseCase1_${ALG}_Test.pem"
    else
        PREV_PCERT="${PLAT_CERT_PATH}TCG_PlatCert_${PC_VERSION}_ServerBareBones_${ALG}_Test.pem"
    fi

    check_plat_cert \
        "${VAR_ISSUER_PATH}" \
        "${VAR_ISSUER_FILE}" \
        "${PLAT_CERT_PATH}" \
        "${PLAT_CERT_FILE}" \
        "${CONFIG_FILE}" \
        "${USECASE2_PS}" \
        --prev-pcert "${PREV_PCERT}"
}

# Check cert chains
echo "Verifying the OEM Certificates"
check_cert_chain "ecc_p256" "OEM" || exit 1
check_cert_chain "ecc_p384" "OEM" || exit 1
check_cert_chain "ecc_p521" "OEM" || exit 1

echo "Verifying the VAR Certificates"
check_cert_chain "ecc_p256" "VAR" || exit 1
check_cert_chain "ecc_p384" "VAR" || exit 1
check_cert_chain "ecc_p521" "VAR" || exit 1

echo "Verifying the TPM Certificates"
check_cert_chain "ecc_p256" "TPM" || exit 1
check_cert_chain "ecc_p384" "TPM" || exit 1
check_cert_chain "ecc_p521" "TPM" || exit 1

echo "Verifying the TPM Endorsement Key Certificates"
check_ek_cert "ecc_p256" || exit 1
check_ek_cert "ecc_p384" || exit 1
check_ek_cert "ecc_p521" || exit 1

# Check Platform Certs
echo "Verifying the v1.1 platform Certificates"
check_plat_certs "ecc_p256" "PC" || exit 1
check_plat_certs "ecc_p384" "PC" || exit 1
check_plat_certs "ecc_p521" "PC" || exit 1

check_plat_certs "ecc_p256" "Server" || exit 1
check_plat_certs "ecc_p384" "Server" || exit 1
check_plat_certs "ecc_p521" "Server" || exit 1

echo
if [ "${ERROR_COUNT}" -ne 0 ]; then
    echo "FAIL: ***** TEST FAILED! **** ${TEST_COUNT} tests were run but there were ${ERROR_COUNT} errors"
    exit 1
else
    echo "PASS: All tests passed! ${TEST_COUNT} tests were run and there were ${ERROR_COUNT} errors."
    exit 0
fi
