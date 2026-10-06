# Platform Certificate Examples

The Platform Certificate test patterns provided by this repo are intended to demonstrate the structure, contents, and relationships of TCG platform certificates across different types (Base vs. Delta), devices (PC vs. Server), supported cryptographic algorithms, and configuration flows (difference in components). The following is a description of use cases reflected by the contents of each test pattern. Each are paired with an example configuration file as another way to view the contents.

## Use Cases & Contents

PC & Server (Bare-Bones):
- Description: A minimal hardware configuration consisting of the core components needed for operation, identity and boot trust.
- Platform Certificate Type: Base
- Components: Chassis, Baseboard, CPU, TPM, BMC (Server only)
- Example configuration file:
  - [v1.1 PC Bare-Bones](../../scripts/config/platform_certs_v1.1/ComponentList_PCBareBones.json)
  - [v1.1 Server Bare-Bones](../../scripts/config/platform_certs_v1.1/ComponentList_ServerBareBones.json)

PC Use Case 1 (Basic):
- Description: An extension of the Bare-bones configuration that includes additional operational components, representing a functional and sellable PC baseline.
- Platform Certificate Type: Base
- Components: Bare-Bones + Memory, Storage, NIC
- Example configuration file:
  - [v1.1 PC Use Case 1](../../scripts/config/platform_certs_v1.1/ComponentList_PCUseCase1.json)

PC Use Case 2 (VAR):
- Description: A VAR of the PC Basic configuration that adds 1 component and replaces 1 component, representing a common device modification.
- Platform Certificate Type: Delta
- Components: Remove Memory, Add Memory (new), Add GPU
- Example configuration file:
  - [v1.1 PC Use Case 2](../../scripts/config/platform_certs_v1.1/ComponentList_PCUseCase2.json)
  - [v1.1 PC Use Case 2 (Final state)](../../scripts/config/platform_certs_v1.1/ComponentList_PCUseCase2_FinalState.json)

Server Use Case 1 (Basic):
- Description: An extension of the Bare-bones configuration that includes additional operational components, representing a functional and sellable Server baseline.
- Platform Certificate Type: Base
- Components: Bare-Bones + Memory 8x, Storage, NIC, SSD 8x
- Example configuration file:
  - [v1.1 Server Use Case 1](../../scripts/config/platform_certs_v1.1/ComponentList_ServerUseCase1.json)

Server Use Case 2 (VAR):
- Description: A VAR of the Server Bare-Bones configuration that adds components, representing the modifications done to upgrade a Server Bare-Bones to a Server Basic.
- Platform Certificate Type: Delta
- Components: Add Memory 8x, Storage, NIC, SSD 8x
- Example configuration file:
  - [v1.1 Server Use Case 2](../../scripts/config/platform_certs_v1.1/ComponentList_ServerUseCase2.json)
  - [v1.1 Server Use Case 2 (Final state)](../../scripts/config/platform_certs_v1.1/ComponentList_ServerUseCase2_FinalState.json)

Additional Elements:
- Extensions: All Platform Certificate examples contain standard X.509 certificate extensions. These include Certificate Policies, Authority Information Access (AIA), and CRL Distribution Points, along with their associated identifiers and URIs.
  - Example configuration file: [v1.1 Extensions.json](../../scripts/config/platform_certs_v1.1/Extensions.json)
- Policy Reference: All Platform Certificate examples contain Platform Certificate policy reference information. This includes referenced TCG Platform and Credential specification versions, Platform Class, and TBB security assertions such as Common Criteria, FIPS, ISO 9000, and RTM information.
  - Example configuration file: [v1.1 PolicyReference.json](../../scripts/config/platform_certs_v1.1/PolicyReference.json)

## Organization

Each Platform Certificate is organized by specification version, followed by use case grouping, followed by certificate type, followed by algorithm. The filename also contains this information in addition to the algorithm curve.
* Example:
  ```
  platform_certs/
  ├── v1.1/
  │   └── pc/
  │       └── attribute/
  │           └── ecc/
  │               ├── TCG_PlatCert_v1.1_PCBareBones_ecc_p256_Test.pem
  ```
    * Artifact: Platform Certificate
    * TCG Specification Version: 1.1
    * Platform Certificate Type: Attribute
    * Use Case: PC Bare Bones
    * Algorithm: ECC
    * Algorithm Curve: p256
