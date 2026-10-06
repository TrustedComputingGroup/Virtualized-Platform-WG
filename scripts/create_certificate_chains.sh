#!/bin/bash
###################################################################################################################
# This script creates a set of Public Key Certificates and Certificate chains that used by this repo.
# Certificate creation is skipped for any certificates already present.
# All private keys will be generated if the keys are not present in the keys folder.
# Key generation is skipped if the keys are already present.
###################################################################################################################

CERT_DAYS=18262   # 50 years
SN_FILE="ca/serial.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
EXAMPLES_PATH="${SCRIPT_DIR}/../examples"
PRIVATE_KEY_PATH="${SCRIPT_DIR}/keys"
ECC_KEY_PATH="${PRIVATE_KEY_PATH}/ecc"

# Setup opensssl ca files and folders
pushd "${CONFIG_DIR}" > /dev/null 2>&1 || exit # openssl ca needs to be above the ca folder
# Start from  known db since certs will be recreated
rm  -rf ca

mkdir -p ca/certs
touch ca/db

# Check dependencies for existing certs, warn if not found
check_dependency() {
	# Check for missing parts of current chain
    if [ -f "${ROOT_CERT}" ] || [ -f "${LEAF_CERT}" ] || [ -f "${CHAIN_CERT}" ]; then
        echo "WARNING: Partial chain detected for $ORG_NAME $ALG $ALG_OPTION."
        echo "       ROOT: $ROOT_CERT"
        echo "       LEAF: $LEAF_CERT"
        echo "       CHAIN: $CHAIN_CERT"
        echo "       If 1 part of PKI chain is being regenerated, you may also need to regenerate all parts of PKI chain. See /scripts/README.md for more details."
    fi

    # Check dependencies for existing certs, warn if not found
    for curve in 256 384 521; do
        TPM_LEAF="${EXAMPLES_PATH}/certificate_chains/tpm/ecc/leaf/TCG_TPM_ecc_p${curve}_TestCA_Leaf.pem"
        EK_CERT="${EXAMPLES_PATH}/tpm_endorsement_certs/ecc/TCG_EK_ecc_p${curve}_Test.pem"

        if [ ! -f "${TPM_LEAF}" ]; then
            if [ -f "${EK_CERT}" ]; then
                echo "WARNING: TPM PKI chain is missing but EK certificate for ECC p${curve} still exists:"
                echo "       $EK_CERT"
                echo "       If TPM PKI is being regenerated, you may also need to regenerate EK certificate. See /scripts/README.md for more details."
            fi
        fi
    done

    for curve in 256 384 521; do
        OEM_LEAF="${EXAMPLES_PATH}/certificate_chains/oem/ecc/leaf/TCG_OEM_ecc_p${curve}_TestCA_Leaf.pem"
        PC_BAREBONES="${EXAMPLES_PATH}/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCBareBones_ecc_p${curve}_Test.pem"
        PC_UC1="${EXAMPLES_PATH}/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase1_ecc_p${curve}_Test.pem"
        SERVER_BAREBONES="${EXAMPLES_PATH}/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerBareBones_ecc_p${curve}_Test.pem"
        SERVER_UC1="${EXAMPLES_PATH}/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerUseCase1_ecc_p${curve}_Test.pem"

        if [ ! -f "${OEM_LEAF}" ]; then
            OEM_CHILDREN=()
            for PLAT_CERT in "${PC_BAREBONES}" "${PC_UC1}" "${SERVER_BAREBONES}" "${SERVER_UC1}"; do
                if [ -f "${PLAT_CERT}" ]; then
                    OEM_CHILDREN+=("${PLAT_CERT}")
                fi
            done
            if [ "${#OEM_CHILDREN[@]}" -gt 0 ]; then
                echo "WARNING: OEM PKI Chain is missing but Base Platform Certificates for ECC p${curve} still exists:"
                for cert in "${OEM_CHILDREN[@]}"; do
                    echo "       $cert"
                done
                echo "       If OEM PKI is being regenerated, you may also need to regenerate Base Platform Certificates. See /scripts/README.md for more details."
            fi
        fi
    done
    for curve in 256 384 521; do
        VAR_LEAF="${EXAMPLES_PATH}/certificate_chains/var/ecc/leaf/TCG_VAR_ecc_p${curve}_TestCA_Leaf.pem"
        PC_UC2="${EXAMPLES_PATH}/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase2_ecc_p${curve}_Test.pem"
        SERVER_UC2="${EXAMPLES_PATH}/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerUseCase2_ecc_p${curve}_Test.pem"

        if [ ! -f "${VAR_LEAF}" ]; then
            VAR_CHILDREN=()
            for PLAT_CERT in "${PC_UC2}" "${SERVER_UC2}"; do
                if [ -f "${PLAT_CERT}" ]; then
                    VAR_CHILDREN+=("${PLAT_CERT}")
                fi
            done
            if [ "${#VAR_CHILDREN[@]}" -gt 0 ]; then
                echo "WARNING: VAR PKI Chain is missing but Delta Platform Certificate for ECC p${curve} still exists:"
                for cert in "${VAR_CHILDREN[@]}"; do
                    echo "       $cert"
                done
                echo "       If VAR PKI is being regenerated, you may also need to regenerate Delta Platform Certificates. See /scripts/README.md for more details."
            fi
        fi
    done
}

# Extracts EC keys from RFC 9500 public page
create_rfc9500_keys() {
    local RFC_URL="https://www.rfc-editor.org/rfc/rfc9500.txt"
    local TMP_FILE
    local P256_KEY="${ECC_KEY_PATH}/rfc9500_ecc_p256_private.pem"
    local P384_KEY="${ECC_KEY_PATH}/rfc9500_ecc_p384_private.pem"
    local P521_KEY="${ECC_KEY_PATH}/rfc9500_ecc_p521_private.pem"

    # Nothing to do if all RFC 9500 keys already exist
    if [ -f "${P256_KEY}" ] &&
       [ -f "${P384_KEY}" ] &&
       [ -f "${P521_KEY}" ]; then
        echo "RFC 9500 EC test keys already exist, skipping download."
        return 0
    fi

    # Creating directories
    mkdir -p "${ECC_KEY_PATH}" || {
        echo "ERROR: Failed to create ${ECC_KEY_PATH}"
        return 1
    }
    TMP_FILE="$(mktemp)" || {
        echo "ERROR: Failed to create temporary file."
        return 1
    }

    echo "Downloading RFC 9500 keys..."
    if ! curl --fail --silent --show-error --location \
        "${RFC_URL}" \
        --output "${TMP_FILE}"; then
        echo "ERROR: Failed to download RFC 9500 keys."
        rm -f "${TMP_FILE}"
        return 1
    fi

    extract_rfc9500_ec_key() {
        local LABEL="$1"
        local OUTPUT_RFC_KEY="$2"

        # Preserve an existing key if only some of the RFC keys are missing.
        if [ -f "${OUTPUT_RFC_KEY}" ]; then
            echo "${OUTPUT_RFC_KEY} already exists, skipping extraction."
            return 0
        fi

        awk -v LABEL="${LABEL}" '
            index($0, LABEL " key in encoded form:") {
                found_label = 1
                next
            }

            found_label && /-----BEGIN EC PRIVATE KEY-----/ {
                copying = 1
            }

            copying {
                sub(/^[[:space:]]+/, "")
                print
            }

            copying && /-----END EC PRIVATE KEY-----/ {
                exit
            }
        ' "${TMP_FILE}" > "${OUTPUT_RFC_KEY}"

        if ! openssl ec \
            -in "${OUTPUT_RFC_KEY}" \
            -check \
            -noout >/dev/null 2>&1; then
            echo "ERROR: Failed to extract a valid ${LABEL} private key."
            rm -f "${OUTPUT_RFC_KEY}"
            return 1
        fi

        chmod 600 "${OUTPUT_RFC_KEY}"
        echo "Created ${OUTPUT_RFC_KEY}"
    }

    for CURVE in 256 384 521; do
        extract_rfc9500_ec_key \
            "P${CURVE}" \
            "${ECC_KEY_PATH}/rfc9500_ecc_p${CURVE}_private.pem" || {
            rm -f "${TMP_FILE}"
            return 1
        }
    done

    rm -f "${TMP_FILE}"
    unset -f extract_rfc9500_ec_key
}

# Creates a leaf cert once a root key and cert has been created.
create_ca_leaf_cert () {
    local CA_ROOT_CERT="$1"
    local CA_ROOT_KEY="$2"
    local LEAF_CERT_OUT="$3"
    local LEAF_KEY_OUT="$4"
    local LEAF_DN="$5"
    local LEAF_NAME="$6"
    local ALG="$7"
    local ALG_OPTION="$8"
    local LEAF_SN="$9"
    local GEN_ALG

    if [[ "${ALG}" == *"ecc"* ]]; then
        GEN_ALG="EC"
    else
        echo "ERROR: Unsupported algorithm: ${ALG}" >&2
        return 1
    fi

    # Create Leaf CA private key if it does not already exist.
    if [ ! -f "${LEAF_KEY_OUT}" ]; then
        echo "Creating new private key for ${LEAF_KEY_OUT}"
        openssl genpkey -algorithm "${GEN_ALG}" -pkeyopt "ec_paramgen_curve:${ALG_OPTION}" -out "${LEAF_KEY_OUT}" || {
            echo "ERROR: Failed to generate leaf key: ${LEAF_KEY_OUT}" >&2
            return 1
        }
    else
        echo "${LEAF_NAME}.key exists, skipping key creation."
    fi

    if [ ! -f "${LEAF_CERT_OUT}" ]; then
        echo "Creating ${ALG} cert for ${LEAF_KEY_OUT} with DN=${LEAF_DN}"
        # Create Single Leaf CA Cert6 with SHA256 for signing Platform Certificates
        openssl req -new -key "${LEAF_KEY_OUT}" -out "${LEAF_NAME}".csr -sha384 -subj "${LEAF_DN}" || {
            echo "ERROR: openssl req failed for ${LEAF_NAME}"
            return 1
        }

        printf '%s\n' "${LEAF_SN}" > "${SN_FILE}"
        openssl ca -config "ca.conf" -days "${CERT_DAYS}" \
        -keyfile "${CA_ROOT_KEY}" \
        -cert "${CA_ROOT_CERT}" \
        -subj "${LEAF_DN}" \
        -in "${LEAF_NAME}".csr \
        -extensions ca_extensions \
        -out "${LEAF_CERT_OUT}" \
        -batch || {
            echo "ERROR: openssl ca failed for ${LEAF_NAME}"
            rm -f "${LEAF_NAME}".csr
            return 1
        }

        rm -f "${LEAF_NAME}.csr"
    else
        echo "${LEAF_NAME}.pem exists, skipping certificate generation."
    fi
}

# Create key directories if they do not already exist.
create_rfc9500_keys || exit 1

# Create a certificate chain (Root CA and 1 Leaf CA).
create_chain () {
    local ORG_NAME="$1"
    local ALG="$2"
    local ALG_OPTION="$3"
    local ROOTCA_SN="$4"
    local LEAF_SN="$5"
    local ALG_SHORT

    if [[ "${ALG}" == "ecc" ]]; then
        ALG_SHORT="ecc"
    else
        echo "ERROR: Unsupported algorithm: ${ALG}" >&2
        return 1
    fi

    if [[ -n "${ALG_OPTION}" ]]; then
        ALG_LONG="${ALG,,}_${ALG_OPTION/-/}"
    else
        ALG_LONG="${ALG,,}"
    fi

    KEY_PATH="$PRIVATE_KEY_PATH/${ALG_SHORT}/"
    RFC_9500_PRIVATE_KEY="rfc9500_${ALG_LONG,,}_private.pem"

    # Root Setup
    ROOT_DN="/C=US/O=TCG/OU=Testing/CN=Example ${ALG_LONG,,} Test ${ORG_NAME} Root CA";
    ROOT_KEY="${KEY_PATH}${RFC_9500_PRIVATE_KEY}"
    ROOT_PATH="${EXAMPLES_PATH}/certificate_chains/${ORG_NAME,,}/${ALG_SHORT,,}/root/"
    ROOT_NAME="TCG_${ORG_NAME}_${ALG_LONG,,}_TestRootCA"
    ROOT_CERT="${ROOT_PATH}${ROOT_NAME}.pem"

    # Leaf Setup
    LEAF_DN="/C=US/O=TCG/OU=Testing/CN=Example ${ALG_LONG,,} Test ${ORG_NAME} Leaf CA";
    LEAF_PATH="${EXAMPLES_PATH}/certificate_chains/${ORG_NAME,,}/${ALG_SHORT,,}/leaf/"
    LEAF_NAME="TCG_${ORG_NAME}_${ALG_LONG,,}_TestCA_Leaf"
    LEAF_CERT="${LEAF_PATH}${LEAF_NAME}.pem"
    LEAF_KEY="${KEY_PATH}${LEAF_NAME}.key"

    # Chain Setup
    CHAIN_PATH="${EXAMPLES_PATH}/certificate_chains/${ORG_NAME,,}/${ALG_SHORT,,}/chain/"
    CHAIN_NAME="TCG_${ORG_NAME}_${ALG_LONG,,}_Test_CertChain"
    CHAIN_CERT="${CHAIN_PATH}${CHAIN_NAME}.pem"

    # Skip generation if PKI already exists
    if [ -f "${ROOT_CERT}" ] && [ -f "${LEAF_CERT}" ] && [ -f "${CHAIN_CERT}" ]; then
        echo "All certificates for ${ORG_NAME} $ALG ${ALG_OPTION} chain already exists, skipping."
        return 0
    fi

    # Warn user of potential issues when a deleted certificate has a dependency
    check_dependency
    # Create Root CA Certificate

    # The OEM RootCa will use the rfc-9500 key, all others will use agenerated key
    if [ ! -f "${ROOT_CERT}" ]; then
        if [ "${ORG_NAME}" == "OEM" ]; then
            # Using rfc-9500 key for the OEM key
            openssl req -new -config "ca.conf" -x509 -days "${CERT_DAYS}" -key "${ROOT_KEY}" -subj "${ROOT_DN}" \
            -set_serial "${ROOTCA_SN}" -extensions ca_extensions -out "${ROOT_CERT}" -text;
            echo " Created ${ALG} ${ORG_NAME} CA Root Cert ${ROOT_CERT} using ${ROOT_KEY}";
        else # Generating a key for all other keys
            ROOT_KEY="${KEY_PATH}${ROOT_NAME}.key"   # Dont use rfc-9500 keys
            GEN_ALG="EC"  #Needed for genpkey
            if [ ! -f "${ROOT_KEY}" ]; then
                echo "Generating Root key for ${ORG_NAME} using ${GEN_ALG} with ${ALG_OPTION}"
                openssl genpkey -algorithm "${GEN_ALG}" -pkeyopt ec_paramgen_curve:"${ALG_OPTION}" -out "${ROOT_KEY}"
            else
                echo "${ROOT_NAME}.key exists, skipping key generation.."
            fi
            if [ ! -f "${ROOT_CERT}" ]; then
                echo "Generating Root Cert for ${ORG_NAME} using ${GEN_ALG} with ${ALG_OPTION}"
                openssl req -new -config ca.conf -x509 -days "${CERT_DAYS}" -key "${ROOT_KEY}" -subj "${ROOT_DN}" \
                -set_serial "${ROOTCA_SN}" -extensions ca_extensions -out "${ROOT_CERT}" -text
            else
                echo "${ROOT_NAME}.pem certificate exists, skipping certificate generation..."
            fi
        fi
    fi
    # Make sure correct Root_key is used if Cert does exist
    if [ "${ORG_NAME}" != "OEM" ]; then
        ROOT_KEY="${KEY_PATH}${ROOT_NAME}.key"
    fi

    # Create Leaf CA Certificate
    create_ca_leaf_cert "${ROOT_CERT}" "${ROOT_KEY}" "${LEAF_CERT}" "${LEAF_KEY}" "${LEAF_DN}" "${LEAF_NAME}" "${ALG}" "${ALG_OPTION}" "${LEAF_SN}" || {
        echo "ERROR: Leaf cert generation failed for ${ORG_NAME} ${ALG_OPTION}"
        exit 1
    }

    # Create VAR Certificate Chain file
    echo "Creating Cert Chain stored as ${CHAIN_CERT}"
    cat "${LEAF_CERT}" "${ROOT_CERT}" >  "${CHAIN_CERT}"

    # Verify the leaf cert
    openssl verify -CAfile "${ROOT_CERT}" "${LEAF_CERT}" >/dev/null 2>&1
    VERIFY_STATUS=$?
    if [ "${VERIFY_STATUS}" -eq 0 ]; then
        echo "Openssl verify PASSED for ${ORG_NAME} pki"
    else
        echo "Openssl verify FAILED for ${ORG_NAME} pki, exiting.";
        exit 1;
    fi
}

# Create cert chains
create_chain "OEM" "ecc" "P-256" "1" "50" || exit 1
create_chain "OEM" "ecc" "P-384" "2" "51" || exit 1
create_chain "OEM" "ecc" "P-521" "3" "52" || exit 1

create_chain "VAR" "ecc" "P-256" "4" "53" || exit 1
create_chain "VAR" "ecc" "P-384" "5" "54" || exit 1
create_chain "VAR" "ecc" "P-521" "6" "55" || exit 1

create_chain "TPM" "ecc" "P-256" "7" "56" || exit 1
create_chain "TPM" "ecc" "P-384" "8" "57" || exit 1
create_chain "TPM" "ecc" "P-521" "9" "58" || exit 1

popd > /dev/null 2>&1 || exit
