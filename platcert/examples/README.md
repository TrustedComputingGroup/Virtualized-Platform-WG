# Examples

This directory contains the example artifacts referenced throughout this repository. Together, they demonstrate a complete ecosystem in which a Platform Certificate would function, including the supporting Public Key Infrastructure (PKI), TPM Endorsement Key (EK) Certificates, and Platform Certificates used to represent example PC and Server platforms.

Although each artifact type is documented separately, they are intended to be used together. The TPM Vendor, OEM, and VAR each maintain their own PKI, which is used to issue certificates corresponding to their role in the supply chain. The relationships between these actors and artifacts are illustrated below.

## Actors
```
  .------------.   .-----.         .-----.      .-------.
  | TPM Vendor |-->| OEM |-------->| VAR |----->| Owner |
  '------------'   '-----'         '-----'      '-------'
   Creates TPM     Creates         Creates         Uses
     EK Cert     Base PlatCert  Delta PlatCert   Verifier
```
The Actors utilized by this repository are:

**TPM Vendor**: The manufacturer of the Trusted Platform Module and issuer of the Endorsement Key Certificate(s). The TPM Vendor maintains a PKI to sign TPM EK Certificates for each TPM it produces.

**Original Equipment Manufacturer (OEM)**: The Manufacturer of a Personal Computer (e.g. Laptop) or Server (e.g a Platform). The OEM maintains a PKI to sign base Platform Certificates for each computer it produces. The OEM has direct sales to owners and works though resellers.

**Value Added Reseller (VAR)**: A reseller of OEM equipment that may add or remove components from the OEM products before delivering the computer to the owner. The VAR maintains a PKI to create and sign delta Platform Certificates with the added and/or removed components.

**Owner**: An Entity that purchases the product and operates a **Verifier** that consumes and verifies Platform Certificates and inspects each product for compliance with the set of Platform Certificates.

## Public Key Infrastructure (PKI) Example

Each actor maintains an independent PKI that is used to issue and validate the certificates associated with its role. The relationship between these PKIs and the certificates they produce is illustrated below.

```
 .-------------.                .-------------.                           .-------------.
 | TPM Root CA |                | OEM Root CA |                           | VAR Root CA |
 '-------------'                '-------------'                           '-------------'
       |                               |                                         |
 .------------.            .-----------------------------.          .-----------------------------.
 | TPM EK CA  |            | OEM Platform Certificate CA |          | VAR Platform Certificate CA |
 '------------'            '-----------------------------'          '-----------------------------' 
        |                              |                                         |
.--------------.            .---------------------------.             .---------------------------.
| TPM EK Cert  |<-Holder-.--| Base Platform Certificate |<-Holder-.--| Delta Platform Certificate |
'--------------'      .--|  '---------------------------'      .--|  '----------------------------'
                      |  '---------------------------'         |  '----------------------------'
                      '---------------------------'            '----------------------------'     
```
Each set of certificates is organized under algorithm type with Root (e.g. OEM Root CA), Leaf (e.g. TPM EK CA), and Chain sub-folders. A Chain is a combined Root CA and Leaf CA file which can be use by openssl to verify an issued certificate (e.g. VAR Chain can be used to verify a Delta Platform Certificate). The Root Certificates are only used to verify the Leaf Certificates. Currently only the Elliptic Curve (ecc) Algorithm is supported for the p256, p384, and p521 curves. Support for other algorithms may be added in the future.

The PKI certificate chain files can be used to verify the corresponding certificates. The TPM certificate chains (organized by algorithm and key size) can be used to verify the corresponding TPM Endorsement Key (EK) Certificates. The OEM certificate chains can be used to verify the corresponding Base Platform Certificates, and the VAR certificate chains can be used to verify the corresponding Delta Platform Certificates.

Example PKI certificate path and file:

```
├── examples
│    └── certificate_chains
│         └── oem
│              └── ecc
│                   └── root
│                        ├── TCG_OEM_ecc_p256_TestRootCA.pem
```
PKI example certificates can be found in [examples/certificate_chains](certificate_chains).

The TPM Vendor PKI issues TPM EK Certificates, while the OEM and VAR PKIs issue Base and Delta Platform Certificates, respectively. The following sections describe each artifact type in more detail.

## TPM Endorsement Key Certificates (EK Cert) Examples

A TCG (Trusted Computing Group) Endorsement Key (EK) Certificate is a credential for a TPM provided by the manufacturer, confirming it is a genuine, secure hardware device.

The EK Certificate can be referenced by the Base Platform Certificate `Holder` field in order to link the Platform Certificate to a specific TPM (and by inference, the device the TPM was embedded into).

In this example, the TPM Vendor creates a Leaf CA that is exclusively used to sign TPM EK Certificates. The TPM Vendors Certificate Chain can be used to verify the Ek Certificate. For simplicity there is only one EK certificate per supported ECC curve (P-256, P-384, P-521), and each corresponding example Base Platform Certificate references the respective EK certificate in their Holder fields.

* Note that a Platform Certificate that uses a `Holder` field is not considered valid unless the EK Certificate it points to is also validated.

* Note that every TPM compliant with the TCG PC Client Platform TPM Profile will have multiple EK certificates. The additional certificates would be captured in the AC Targeting extension. These examples do not include additional EK Certificates.

Example EK certificate path and file:

```
├── examples
│    └── tpm_endorsement_certs
│         └── ecc
│              ├── TCG_EK_ecc_p256_Test.pem
```

TPM EK Certificate examples can be found in [examples/tpm_endorsement_certs](tpm_endorsement_certs).

## Platform Certificate Examples

Platform Certificate examples in this repository includes types Base and Delta. The scenarios for each example use one of two platform types: PC Client (PC) and Server.

The following example use cases illustrate common supply chain scenarios represented by the certificates in this repository. There are additional platform types, configurations and use cases that are not covered by these samples.

**1**. OEM configures Basic devices for direct sale (or retail).

```
  .------------.   .-----.       .-------.
  | TPM Vendor |-->| OEM |------>| Owner |
  '------------'   '-----'       '-------'
  Creates TPM      Creates         Uses
    EK Cert       Base PlatCert   Verifier
                  (UseCase1)
```

**2**. VAR obtains product from the OEM and replaces a component with another (e.g. Memory) and adds a another (e.g. GPU) before delivering the computer to the owner.

```
 .------------.    .-----.           .-----.        .-------.
 | TPM Vendor |--->| OEM |---------> | VAR |------->| Owner |
 '------------'    '-----'           '-----'        '-------'
 Creates TPM       Creates           Creates          Uses
   EK Cert       Base PlatCert    Delta PlatCert     Verifier
                 (UseCase1)        (UseCase2)
```
The example configurations used by these Platform Certificates are:
* **BareBones**: (Not for resale) Chassis + baseboard + CPU + TPM + BMC (if server)
* **UseCase1**: Bare-bones + memory + storage + NIC
* **UseCase2**: Bare-bones + memory upgrade + storage + NIC + GPU

The PC Client and Server examples use different component inventories. For example, the PC examples include one memory component and one storage component, while the Server examples include eight memory components and eight storage components. For exact details on the components used for the configuration please refer to the [README.md in the platform_certs folder](platform_certs/README.md).

For Platform Certificate Profile Version 1.1, X.509 Public Key Certificate encoding was not supported and is therefore not included in the current examples. Later versions of the specification reintroduced support for Public Key Certificate–encoded Platform Certificates, and corresponding examples are planned for a future release.

Example Platform Certificate path and file:

```
├── examples
│    └── platform_certs
│         └── v1.1
│              └── pc
│                   └── attribute
│                        └── ecc
│                             ├── TCG_PlatCert_v1.1_PCBareBones_ecc_p256_Test.pem
```

Platform Certificate examples can be found in [examples/platform_certs](platform_certs).
