#!/bin/bash

###########################################################################################
# This script creates Test Endorsement Key Certificates referenced by the
# Platform Certificate Holder field for Platform Certificate generated for this repo.
###########################################################################################

EK_DAYS=16436
SN_FILE="ca/serial.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
EXAMPLES_PATH="${SCRIPT_DIR}/../examples"
PRIVATE_KEY_PATH="${SCRIPT_DIR}/keys"

# ECC paths
PRIVATE_ECC_KEY_PATH="${PRIVATE_KEY_PATH}/ecc/"
EK_ECC_CERT_PATH="${EXAMPLES_PATH}/tpm_endorsement_certs/ecc/"
CHAIN_ECC_PATH="${EXAMPLES_PATH}/certificate_chains/tpm/ecc/chain/"
LEAF_ECC_PATH="${EXAMPLES_PATH}/certificate_chains/tpm/ecc/leaf/"

# Check dependencies for existing certs, warn if not found
check_dependency() {
    CURVE="$1"
    EK_CERT="${EK_ECC_CERT_PATH}TCG_EK_ecc_p${CURVE}_Test.pem"
    PLATFORM_BASE_PATH="${EXAMPLES_PATH}/platform_certs/v1.1"
    BASE_CERTS=()

    for USE_CASE in PCBareBones PCUseCase1 ServerBareBones ServerUseCase1; do
        if [[ "$USE_CASE" == Server* ]]; then
            PLATFORM_CERT="${PLATFORM_BASE_PATH}/server/attribute/ecc/TCG_PlatCert_v1.1_${USE_CASE}_ecc_p${CURVE}_Test.pem"
        else
            PLATFORM_CERT="${PLATFORM_BASE_PATH}/pc/attribute/ecc/TCG_PlatCert_v1.1_${USE_CASE}_ecc_p${CURVE}_Test.pem"
        fi

        if [ -f "${PLATFORM_CERT}" ]; then
            BASE_CERTS+=("${PLATFORM_CERT}")
        fi
    done

    if [ "${#BASE_CERTS[@]}" -gt 0 ] && [ ! -f "${EK_CERT}" ]; then
        echo "WARNING: EK Certificate for ECC p${CURVE} is missing but platform certificates that depends on it exists:"
        for cert in "${BASE_CERTS[@]}"; do
            echo "       $cert"
        done
        echo "       If EK is being regenerated, you may also need to regenerate Base Platform Certificates. See /scripts/README.md for more details."
    fi
}

for curve in 256 384 521; do
    check_dependency "${curve}"
done

# Setup openssl ca files and folders

pushd "${CONFIG_DIR}" || exit # openssl ca needs to be above the ca folder

# Start from known db since certs will be recreated
rm -rf ca
mkdir -p "${EK_ECC_CERT_PATH}"
mkdir -p ca/certs
touch ca/db

create_ek_cert() {
    ALG="$1"
    CURVE="$2"
    EK_SN="$3"
    LEAF_KEY="TCG_TPM_${ALG}_TestCA_Leaf.key"
    LEAF_CERT="TCG_TPM_${ALG}_TestCA_Leaf.pem"
    CHAIN_NAME="TCG_TPM_${ALG}_Test_CertChain"
    EK_NAME="TCG_EK_${ALG}_Test"

    # Skip generation if EK already exists
    FULL_EK_PATH="${EK_ECC_CERT_PATH}TCG_EK_${ALG}_Test.pem"
    if [ -f "${FULL_EK_PATH}" ]; then
        echo "${FULL_EK_PATH} already exists, skipping."
        return 0
    fi

    if [[ "$ALG" == *"ecc"* ]]; then
        echo "Processing for ECC"
        EK_KEY_PATH="${PRIVATE_ECC_KEY_PATH}"
        EK_CERT_PATH="${EK_ECC_CERT_PATH}"
        PKI_LEAF_PATH="${LEAF_ECC_PATH}"
        PKI_CHAIN_PATH="${CHAIN_ECC_PATH}"
    else
        echo "$ALG Algorithm not supported"
        exit 1
    fi

    echo "Creating EK key for $ALG"

    # Create Single EK Private Key pair
    openssl genpkey \
        -algorithm "EC" \
        -pkeyopt "ec_paramgen_curve:${CURVE}" \
        -out "${EK_KEY_PATH}${EK_NAME}.key"

    # Create a cert request for the EK
    openssl req \
        -new \
        -key "${EK_KEY_PATH}${EK_NAME}.key" \
        -out "${EK_KEY_PATH}${EK_NAME}.csr" \
        -sha256 \
        -subj "/"

    echo "CSR created, Leaf CA will sign EK cert..."

    printf '%s\n' "${EK_SN}" > "${SN_FILE}"
    if ! openssl ca -config "ca.conf" -days "$EK_DAYS" \
        -keyfile "${EK_KEY_PATH}${LEAF_KEY}" \
        -cert "${PKI_LEAF_PATH}${LEAF_CERT}" \
        -subj "/" \
        -in "${EK_KEY_PATH}${EK_NAME}.csr" \
        -extensions ek_extensions \
        -out "${EK_CERT_PATH}${EK_NAME}.pem" \
        -batch; then
        echo "Openssl CA error while creating EK certificate for $ALG $CURVE. Exiting without creating the EK Certificate."
        exit 1
    fi

    echo "EK Cert Request Processed"

    # remove the request
    rm "${EK_KEY_PATH}${EK_NAME}.csr"

    # Print the new EK cert
    openssl x509 -in "${EK_CERT_PATH}${EK_NAME}.pem" -noout -text

    # Verify the EK cert
    echo ""
    echo "Verifying the EK cert using the appropriate cert chain"
    openssl verify -CAfile "${PKI_CHAIN_PATH}${CHAIN_NAME}.pem" "${EK_CERT_PATH}${EK_NAME}.pem"
    echo ""
}

# Create EK Certs
create_ek_cert "ecc_p256" "P-256" "1000"
create_ek_cert "ecc_p384" "P-384" "1001"
create_ek_cert "ecc_p521" "P-521" "1002"

popd || exit
