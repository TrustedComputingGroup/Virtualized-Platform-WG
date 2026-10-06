# Certificate Chain Examples

This subdirectory contains the example Public Key Infrastructure (PKI) certificate authorities used throughout the repository.

Three independent PKIs are provided, one for each actor in the example scenarios:

- **OEM** – Issues Base Platform Certificates.
- **TPM Vendor** – Issues TPM Endorsement Key (EK) Certificates.
- **VAR** – Issues Delta Platform Certificates.

Each PKI contains three types of artifacts:

- **Root CA** – The trust anchor for the hierarchy.
- **Leaf CA** – The issuing Certificate Authority that signs the example certificates.
- **Certificate Chain** – A single PEM file containing both the Root CA and Leaf CA certificates.

## Organization

Each PKI is organized by actor, followed by cryptographic algorithm, followed by the certificate type. The filename also contains this information in addition to the algorithm curve.
* Example:
  ```
  certificate_chains/
  ├── oem/
  │   └── ecc/
  │       ├── root/
  │           ├── TCG_OEM_ecc_p256_TestRootCA.pem
  ```
  * Artifact: Certificate Authority
  * Actor: OEM
  * Algorithm: ECC
  * Algorithm Curve: p256
  * Certificate Authority Type: Root
