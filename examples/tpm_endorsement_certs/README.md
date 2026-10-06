# TPM Endorsement Key Certificate Examples

This subdirectory contains the example Trusted Platform Module (TPM) Endorsement Key (EK) Certificates used throughout the repository. They are compliant with [TCG EK Credential Profile for TPM Family 2.0 v2.6](https://trustedcomputinggroup.org/wp-content/uploads/TCG-EK-Credential-Profile-for-TPM-Family-2.0-Level-0-Version-2.6_pub.pdf).

The example EK Certificates are issued by the TPM Vendor PKI contained in the [`certificate_chains/tpm`](../certificate_chains/tpm) directory. Each EK Certificate represents the identity of a TPM and is referenced by the Holder field of the example Base Platform Certificates.

## Organization

Each TPM EK Certificate is organized by cryptographic algorithm. The filename also contains the algorithm curve.

* Example:
  ```
  tpm_endorsement_certs/
  └── ecc/
      ├── TCG_EK_ecc_p256_Test.pem
  ```
    * Artifact: TPM Endorsement Key (EK) Certificate
    * Algorithm: ECC
    * Algorithm Curve: p256