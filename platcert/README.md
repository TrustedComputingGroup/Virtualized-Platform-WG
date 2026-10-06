# Introduction

## Problem Statement

This repository enables broader adoption of TCG attestation technologies. One of the key enablers of adoption is the availability of realistic reference artifacts that can be used to guide implementation, verify cryptographic operations, validate software behavior, and promote interoperability between independent implementations.

## About this Repository

This repository provides example [TCG Platform Certificates](https://trustedcomputinggroup.org/resource/tcg-platform-certificate-profile/) and related artifacts to support and promote Platform Certificate adoption. The examples are intended to help developers of attestation artifacts and verifiers to implement, test, validate, and demonstrate interoperable Platform Certificate solutions.

This repository includes the following example artifacts:
* Platform Certificates
  * Developed to [TCG Platform Certificate Profile Version 1.1](https://trustedcomputinggroup.org/wp-content/uploads/IWG_Platform_Certificate_Profile_v1p1_r19_pub_fixed.pdf)
  * Support for later versions of the TCG Platform Certificate Profile may be added in future releases
* PKI Certificate Authorities
  * Developed to [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280)
* TPM Endorsement Key (EK) Certificates
  * Developed to [TCG EK Credential Profile for TPM Family 2.0 v2.6](https://trustedcomputinggroup.org/wp-content/uploads/TCG-EK-Credential-Profile-for-TPM-Family-2.0-Level-0-Version-2.6_pub.pdf)

The repository is organized into a small number of top-level directories:

- **examples** – Contains all example artifacts distributed with this repository, including PKI certificate chains, TPM Endorsement Key (EK) Certificates, and Platform Certificates.
  - The current example artifacts in this repository are ECC-based. Support for additional cryptographic algorithms is planned for future releases.
- **scripts** – Contains the scripts and configuration files used to generate and validate the example artifacts.

Additional documentation is organized throughout the repository in directory-specific `README.md` files:

- **README.md** – Project overview, goals, and repository organization.
- [examples/README.md](examples/README.md) – Overview of the example artifacts and their relationships.
- [examples/certificate_chains/README.md](examples/certificate_chains/README.md) – PKI certificate chains and Certificate Authorities.
- [examples/tpm_endorsement_certs/README.md](examples/tpm_endorsement_certs/README.md) – TPM Endorsement Key (EK) Certificate examples.
- [examples/platform_certs/README.md](examples/platform_certs/README.md) – Platform Certificate examples, use cases, and configurations.
- [scripts/README.md](scripts/README.md) – Certificate generation and validation scripts.

# Background

A **Base Platform Certificate** is a signed certificate that asserts that a specific platform contains one or more unique Roots of Trust (TPM, DICE, etc.), Trusted Building Block(s), and a specific set of components. Platform Configuration attributes within the Platform Certificate can contain a list of individual components that constitute the platform. The component list attribute supports recent calls for a Hardware Bill of Materials (HBOM) artifact. Each component has an extensible set of information that can include attributes such as manufacturer, model, serial number, and, where applicable, network adapter MAC addresses.
* Base Platform Certificates may be encoded as either an X.509 Attribute Certificate compliant with [RFC 5755](https://datatracker.ietf.org/doc/html/rfc5755).
  * An Attribute Certificate is appropriate when the certificate attributes have a different lifecycle than the public key they would otherwise be bound to in a Public Key Certificate.
* This repository currently provides the X.509 Attribute Certificate encoding.

**Delta Platform Certificates** are used to reflect platform changes made by system integrators, resellers, and other entities after the platform has left the manufacturer’s facility.

Any entity can issue a Platform Certificate: the initial (Base) Platform Certificate is typically issued by the platform manufacturer (for example, an OEM).

Platform Certificates, including Delta Platform Certificates, are Endorsements that a **Verifier** uses when evaluating the Evidence provided by an **Attester**. A Verifier determines whether the issuer of a Platform Certificate or Delta Platform Certificate is trusted, and by extension whether the assertions contained therein can be trusted, based on the Appraisal Policy it uses that can be provided by the Relying Party.

Component Class Registries allow the issuer to convey how device information was collected. This helps verifiers match detailed component information independent of the OS and hardware related libraries. Currently defined Component Class Registries include:
* [TCG Component Class Registry](https://trustedcomputinggroup.org/resource/tcg-component-class-registry/)
* [SMBIOS-based Component Class Registry](https://trustedcomputinggroup.org/resource/smbios-based-component-class-registry/)
* [Storage Component Class Registry](https://trustedcomputinggroup.org/resource/storage-component-class-registry/)
* [PCIe-based Component Class Registry](https://trustedcomputinggroup.org/resource/pcie-based-component-class-registry/)

Requirements for Platform Certificates have been documented in the [TCG Platform Requirements for Certificates and RIMs specification](https://trustedcomputinggroup.org/resource/tcg-platform-requirements-for-certificates-and-rims/).

# Test Data

**Private keys used to generate the distributed certificates are not included in this repository and there are no intentions to add them in the future.** When run, the certificate-generation scripts create the required test keys locally under [scripts](scripts). Among these, the OEM Root CA test keys are taken from [RFC 9500](https://www.rfc-editor.org/rfc/rfc9500.html) “Standard Public Key Cryptography (PKC) Test Keys”. All other keys are randomly generated.

Test signature certificates and certificate chains were generated using [NIST guidelines](https://csrc.nist.gov/Projects/pki-testing/x-509-path-validation-test-suite ). All example public key certificates were generated using OpenSSL 3.5.

Platform Certificates were generated using [PACCOR](https://github.com/nsacyber/paccor). Information contained within the Platform Certificates is generic and not based on any commercially available components. The specific values used for the component list can be found in the JSON configuration files used by PACCOR to generate the specific Platform Certificate.

# Specifications and References
* [TCG Platform Certificate Profile](https://trustedcomputinggroup.org/resource/tcg-platform-certificate-profile/)
* [TCG Platform Requirements for Certificates and RIMs](https://trustedcomputinggroup.org/resource/tcg-platform-requirements-for-certificates-and-rims/)
* [TCG EK Credential Profile for TPM Family 2.0](https://trustedcomputinggroup.org/resource/http-trustedcomputinggroup-org-wp-content-uploads-tcg-ek-credential-profile/)
* [TCG Component Class Registry](https://trustedcomputinggroup.org/resource/tcg-component-class-registry/)
* [SMBIOS-based Component Class Registry](https://trustedcomputinggroup.org/resource/smbios-based-component-class-registry/)
* [Storage Component Class Registry](https://trustedcomputinggroup.org/resource/storage-component-class-registry/)
* [PCIe-based Component Class Registry](https://trustedcomputinggroup.org/resource/pcie-based-component-class-registry/)
* [RFC 5280 — Internet X.509 Public Key Infrastructure Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280)
* [RFC 5755 — Internet Attribute Certificate Profile for Authorization](https://datatracker.ietf.org/doc/html/rfc5755)
* [RFC 9500 — Standard Public Key Cryptography Test Keys](https://www.rfc-editor.org/rfc/rfc9500.html)

# Related Open Source Projects and Tools
* [OpenSSL](https://www.openssl.org/)
* [TCG's Fork of OpenSSL](https://github.com/TrustedComputingGroup/openssl) augmented with Attribute Certificate capabilities (waiting for Openssl merge approval)
* [Platform Attribute Certificate Creator](https://github.com/nsacyber/paccor) (PACCOR)
* [Host Integrity and Runtime and Startup](https://github.com/nsacyber/hirs) (HIRS)
* [haskell-tcg-cert](https://github.com/tatac1/haskell-tcg-cert)
