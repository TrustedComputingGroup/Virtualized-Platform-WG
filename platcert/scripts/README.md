# Certificate Generation Scripts

## Purpose

This directory contains the scripts used to generate and validate all example certificates included in the repository. The generated artifacts are written to the [examples](../examples) directory and consist of certificate chains, Endorsement Key (EK) Certificates, and Platform Certificates.

NOTE: These scripts are provided to document how the example certificates in this repository were generated and validated. They are not intended for general purpose certificate generation or verification.

## Prerequisites

These scripts need the following software to be installed:

* [OpenSSL](https://www.openssl.org/) 3.5 or later (see the [OpenSSL Documentation](https://docs.openssl.org/) for installation and usage)
* [PACCOR](https://github.com/nsacyber/paccor) v2.0r10 or later, installed at `/opt/paccor/bin/paccor`
  * The scripts support the `PACCOR_BIN` environment variable, which can be used to specify a custom PACCOR binary path instead of the default `/opt` location.
* [Bash](https://www.gnu.org/software/bash/) 4.0 or later
* Java Development Kit (JDK) 25
* `jq`, used to update JSON configuration files
* `curl`, used to download RFC 9500 reference EC private keys
* Network access to `https://www.rfc-editor.org/` when the RFC 9500 keys are not already present

[create_certificate_chains.sh](create_certificate_chains.sh) uses private keys to generate the example certificates. Given a local clone of this repository, users have two options regarding these keys:
* Place corresponding pre-generated private key files in a `keys/` folder under the `scripts/` directory before running the scripts, as such:
  ```
  scripts/
  ├── keys/
  ```
* If the private key files are not provided manually, [create_certificate_chains.sh](create_certificate_chains.sh) will automatically generate and use new files as needed.

## Certificate Regeneration:

NOTE: Run these scripts as a regular user and avoid using `sudo`. The scripts generate and modify files within the repository. Running them as `root` may cause generated files to be owned by `root`, which can prevent subsequent executions or normal repository operations.

### To modify the contents of a certificate:
1. Modify desired fields of [ca.conf](config/ca.conf) for CA/EK certificates or the [respective configuration JSON file](config) for Platform Certificates.
2. Delete the currently existing certificate, and consider deleting any certificates that depend on it.
   * Example: If Certificate A is used by Certificate B, and A has its DN modified, B now has the incorrect DN from A and will also need to be regenerated. On the other hand, if A only had a policy modified, this would not affect contents in B, and B would not have to be regenerated.
   * Dependencies:
     * All 3 parts of certificate chain (Chain, Root, Leaf) should match each other. If one is to be regenerated, they all should be.
     * TPM CA key certs are used for EK Certificates.
     * OEM CA key certs are used for Base Platform Certificates (PCBareBones, PCUseCase1, ServerBareBones, ServerUseCase1)
     * VAR CA key certs are used for Delta Platform Certificates (PCUseCase2, ServerUseCase2).
     * EK Certificate is holder for Base Platform Certificates (PCBareBones, PCUseCase1, ServerBareBones, ServerUseCase1) encoded as X.509 Attribute Certificates.
     * Platform Certificate PCUseCase2 (Delta) references previously-issued PCUseCase1 (Base).
     * Platform Certificate ServerUseCase2 (Delta) references previously-issued ServerBareBones (Base)
3. From the repository root, run the respective certificate creation script:
   * For Certificate Chains:
     ```
     ./scripts/create_certificate_chains.sh
     ```
   * For EK Certificates:
     ```
     ./scripts/create_tpm_endorsement_certs.sh
     ```
   * For Platform Certificates:
     ```
     ./scripts/create_platform_certs.sh
     ```
4. Run the certificate verification script to ensure new certificates are valid:
   * ```
     ./scripts/check_all_certs.sh
     ```
* <details><summary>Example scenario 1: Developer intends to modify DN of TPM CA for ECC p256. DN change WOULD affect following certs in chain.</summary>

  1. Modify desired fields of [ca.conf](config/ca.conf)
  2. Delete:
    * [TCG_TPM_ecc_p256_Test_CertChain.pem](../examples/certificate_chains/tpm/ecc/chain/TCG_TPM_ecc_p256_Test_CertChain.pem)
    * [TCG_TPM_ecc_p256_TestCA_Leaf.pem](../examples/certificate_chains/tpm/ecc/leaf/TCG_TPM_ecc_p256_TestCA_Leaf.pem)
    * [TCG_TPM_ecc_p256_TestRootCA.pem](../examples/certificate_chains/tpm/ecc/root/TCG_TPM_ecc_p256_TestRootCA.pem)
    * [TCG_EK_ecc_p256_Test.pem](../examples/tpm_endorsement_certs/ecc/TCG_EK_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_PCBareBones_ecc_p256_Test.pem](../examples/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCBareBones_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_PCUseCase1_ecc_p256_Test.pem](../examples/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase1_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_PCUseCase2_ecc_p256_Test.pem](../examples/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase2_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_ServerBareBones_ecc_p256_Test.pem](../examples/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerBareBones_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_ServerUseCase1_ecc_p256_Test.pem](../examples/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerUseCase1_ecc_p256_Test.pem)
    * [TCG_PlatCert_v1.1_ServerUseCase2_ecc_p256_Test.pem](../examples/platform_certs/v1.1/server/attribute/ecc/TCG_PlatCert_v1.1_ServerUseCase2_ecc_p256_Test.pem)
  3. Run:
    * [create_certificate_chains.sh](create_certificate_chains.sh)
    * [create_tpm_endorsement_certs.sh](create_tpm_endorsement_certs.sh)
    * [create_platform_certs.sh](create_platform_certs.sh)
    * [check_all_certs.sh](check_all_certs.sh)

  </details>
* <details><summary>Example scenario 2: Developer intends to add a power supply component to contents of v1.1 Platform Certificate PCUseCase1 for ECC p384. Component mod would NOT affect following certs in chain.</summary>

  1. Add power supply component to [ComponentList_PCUseCase1.json](config/platform_certs_v1.1/ComponentList_PCUseCase1.json)
  2. Delete:
    * [TCG_PlatCert_v1.1_PCUseCase1_ecc_p384_Test.pem](../examples/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase1_ecc_p384_Test.pem)
    * [TCG_PlatCert_v1.1_PCUseCase2_ecc_p384_Test.pem](../examples/platform_certs/v1.1/pc/attribute/ecc/TCG_PlatCert_v1.1_PCUseCase2_ecc_p384_Test.pem)
  3. Run:
    * [create_platform_certs.sh](create_platform_certs.sh)
    * [check_all_certs.sh](check_all_certs.sh)

  </details>
* <details><summary>Example scenario 3: Developer intends to modify policy of OEM CA for all ECC curves. Policy change would NOT affect following certs in chain.</summary>

  1. Modify desired fields of [ca.conf](config/ca.conf)
  2. Delete:
    * [TCG_OEM_ecc_p256_Test_CertChain.pem](../examples/certificate_chains/oem/ecc/chain/TCG_OEM_ecc_p256_Test_CertChain.pem)
    * [TCG_OEM_ecc_p384_Test_CertChain.pem](../examples/certificate_chains/oem/ecc/chain/TCG_OEM_ecc_p384_Test_CertChain.pem)
    * [TCG_OEM_ecc_p521_Test_CertChain.pem](../examples/certificate_chains/oem/ecc/chain/TCG_OEM_ecc_p521_Test_CertChain.pem)
    * [TCG_OEM_ecc_p256_TestCA_Leaf.pem](../examples/certificate_chains/oem/ecc/leaf/TCG_OEM_ecc_p256_TestCA_Leaf.pem)
    * [TCG_OEM_ecc_p384_TestCA_Leaf.pem](../examples/certificate_chains/oem/ecc/leaf/TCG_OEM_ecc_p384_TestCA_Leaf.pem)
    * [TCG_OEM_ecc_p521_TestCA_Leaf.pem](../examples/certificate_chains/oem/ecc/leaf/TCG_OEM_ecc_p521_TestCA_Leaf.pem)
    * [TCG_OEM_ecc_p256_TestRootCA.pem](../examples/certificate_chains/oem/ecc/root/TCG_OEM_ecc_p256_TestRootCA.pem)
    * [TCG_OEM_ecc_p384_TestRootCA.pem](../examples/certificate_chains/oem/ecc/root/TCG_OEM_ecc_p384_TestRootCA.pem)
    * [TCG_OEM_ecc_p521_TestRootCA.pem](../examples/certificate_chains/oem/ecc/root/TCG_OEM_ecc_p521_TestRootCA.pem)
  3. Run:
    * [create_certificate_chains.sh](create_certificate_chains.sh)
    * [check_all_certs.sh](check_all_certs.sh)    
  </details>
## Notes:

### Certificate Chains:

* Running [create_certificate_chains.sh](create_certificate_chains.sh) will create:
  * A `scripts/config/ca` folder which will have a OpenSSL database which tracks certificate serial numbers. 
  * A `scripts/keys` folder (if it does not already exist), in which private keys are generated to be used in CA creation. Some of these keys are downloaded from [RFC 9500](https://datatracker.ietf.org/doc/rfc9500/).
* Root CA certificate serial numbers begin at decimal 1 and increment across the generated certificate chains. Leaf CA serial numbers start at decimal 80 and increment by one for each leaf.
* Three ECC certificate chains were created for p256, p384, and p521 curves.
* The certificate chain `.pem` files include extra OpenSSL text and can be viewed using a standard text editor.

<details>
<summary>Example OpenSSL text output for <code>TCG_OEM_ecc_p256_TestCA_Leaf.pem</code></summary>

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 80 (0x50)
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: C=US, O=TCG, OU=Testing, CN=Example ecc_p256 Test OEM Root CA
        Validity
            Not Before: Jul 29 21:21:47 2026 GMT
            Not After : Jul 28 21:21:47 2076 GMT
        Subject: C=US, O=TCG, OU=Testing, CN=Example ecc_p256 Test OEM Leaf CA
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:5e:82:f4:60:ba:89:b8:38:8d:46:db:c0:53:3e:
                    5c:c2:d3:01:a9:0a:08:d4:96:e8:92:a9:98:f1:9f:
                    10:52:89:2b:a3:04:11:27:69:f4:cd:8e:0c:38:99:
                    86:de:3a:15:4f:da:bc:c0:d6:61:8c:66:d0:f9:a7:
                    87:33:e6:ef:a2
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Subject Key Identifier: 
                53:59:25:BC:30:AB:52:EF:14:31:98:A4:5B:DB:CB:2C:DA:DD:FC:FF
            X509v3 Authority Key Identifier: 
                5B:70:A7:98:17:F7:9F:F6:37:D2:F7:E3:DC:44:6C:21:09:D7:BB:D4
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
            Authority Information Access: 
                CA Issuers - URI:https://example.invalid/certs
            X509v3 CRL Distribution Points: 
                Full Name:
                  URI:https://example.invalid/crl

            X509v3 Certificate Policies: 
                Policy: 2.16.840.1.101.3.1.48
    Signature Algorithm: ecdsa-with-SHA256
    Signature Value:
        30:44:02:20:5b:31:4d:ab:2e:7d:99:29:9a:c1:ec:80:34:a9:
        e5:c6:48:05:23:18:43:ad:1c:ab:bb:62:36:53:ce:ac:3e:fb:
        02:20:19:3f:aa:6a:47:71:72:1e:c0:1f:4b:af:c3:02:34:1f:
        27:0f:f7:89:88:30:ea:3e:88:9f:db:93:2b:41:d1:7e
```

</details>

### TPM EK Certificates:

* EK Certs produced by [create_tpm_endorsement_certs.sh](create_tpm_endorsement_certs.sh) are given serial numbers that start with decimal 4096 and gets incremented by 1 for each cert.
* Three ECC EK Certs were created for p256, p384, and p521 curves.
* The EK cert `.pem` files include extra OpenSSL text and can be viewed using a standard text editor.

<details>
<summary>Example OpenSSL text output for <code>TCG_EK_ecc_p256_Test.pem</code></summary>

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 4096 (0x1000)
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: C=US, O=TCG, OU=Testing, CN=Example ecc_p256 Test TPM Leaf CA
        Validity
            Not Before: Jul 29 21:22:44 2026 GMT
            Not After : Jul 29 21:22:44 2071 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:73:b2:b1:0c:db:ce:fd:f5:af:5f:55:28:39:35:
                    ef:19:76:b2:e9:0e:f9:4e:7b:cb:c7:01:1b:e3:34:
                    53:e2:8e:05:ca:3e:42:e3:78:f3:9b:3d:aa:f6:32:
                    77:ae:8d:fb:4a:ae:18:ee:bf:9f:5f:05:d3:e2:a1:
                    09:ed:eb:f7:52
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Key Encipherment
            X509v3 Subject Key Identifier: 
                F6:64:29:2D:1C:F0:67:A8:BF:19:96:B6:65:DE:B5:69:6A:90:76:76
            X509v3 Authority Key Identifier: 
                5F:9A:EE:3D:17:B8:1E:B7:96:D6:BB:EE:EB:9A:E3:99:61:DF:6D:24
            Authority Information Access: 
                CA Issuers - URI:https://example.invalid/certs/
            X509v3 CRL Distribution Points: 
                Full Name:
                  URI:https://example.invalid/crl

            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Certificate Policies: 
                Policy: 2.16.840.1.101.3.1.48
            X509v3 Extended Key Usage: 
                Endorsement Key Certificate
            X509v3 Subject Alternative Name: critical
                DirName:/tcg-at-tpmManufacturer=id:54535430/tcg-at-tpmModel=ABCDEF123456/tcg-at-tpmVersion=id:01
            X509v3 Subject Directory Attributes: 
                TPM Specification:
    0:d=0  hl=2 l=  11 cons: SEQUENCE          
    2:d=1  hl=2 l=   3 prim:  UTF8STRING        :2.0
    7:d=1  hl=2 l=   1 prim:  INTEGER           :00
   10:d=1  hl=2 l=   1 prim:  INTEGER           :63

                TPM Security Assertions:
    0:d=0  hl=4 l= 338 cons: SEQUENCE          
    4:d=1  hl=2 l=   1 prim:  INTEGER           :00
    7:d=1  hl=2 l=   1 prim:  BOOLEAN           :0
   10:d=1  hl=2 l=   1 prim:  cont [ 0 ]        
   13:d=1  hl=2 l=   1 prim:  cont [ 1 ]        
   16:d=1  hl=2 l=   1 prim:  cont [ 2 ]        
   19:d=1  hl=4 l= 263 cons:  cont [ 3 ]        
   23:d=2  hl=2 l=   3 prim:   IA5STRING         :3.1
   28:d=2  hl=2 l=   1 prim:   ENUMERATED        :01
   31:d=2  hl=2 l=   1 prim:   ENUMERATED        :00
   34:d=2  hl=2 l=   1 prim:   BOOLEAN           :0
   37:d=2  hl=2 l=   1 prim:   cont [ 0 ]        
   40:d=2  hl=2 l=   5 prim:   cont [ 1 ]        
   47:d=2  hl=2 l= 114 cons:   cont [ 2 ]        
   49:d=3  hl=2 l=  30 prim:    IA5STRING         :https://example.invalid/cc-uri
   81:d=3  hl=2 l=  13 cons:    SEQUENCE          
   83:d=4  hl=2 l=   9 prim:     OBJECT            :rsaEncryption
   94:d=4  hl=2 l=   0 prim:     NULL              
   96:d=3  hl=2 l=  65 prim:    BIT STRING        
      0000 - 00                                                .
  163:d=2  hl=2 l=   5 prim:   cont [ 3 ]        
  170:d=2  hl=2 l= 114 cons:   cont [ 4 ]        
  172:d=3  hl=2 l=  30 prim:    IA5STRING         :https://example.invalid/cc-uri
  204:d=3  hl=2 l=  13 cons:    SEQUENCE          
  206:d=4  hl=2 l=   9 prim:     OBJECT            :rsaEncryption
  217:d=4  hl=2 l=   0 prim:     NULL              
  219:d=3  hl=2 l=  65 prim:    BIT STRING        
      0000 - 00                                                .
  286:d=1  hl=2 l=  13 cons:  cont [ 4 ]        
  288:d=2  hl=2 l=   5 prim:   IA5STRING         :140-2
  295:d=2  hl=2 l=   1 prim:   ENUMERATED        :01
  298:d=2  hl=2 l=   1 prim:   BOOLEAN           :0
  301:d=1  hl=2 l=   1 prim:  cont [ 5 ]        
  304:d=1  hl=2 l=  36 prim:  IA5STRING         :https://example.invalid/iso9000-cert


    Signature Algorithm: ecdsa-with-SHA256
    Signature Value:
        30:44:02:20:4c:ad:7e:d7:d5:ec:a7:95:2c:94:2b:f3:96:74:
        63:cd:43:9a:aa:e1:71:f0:3c:68:d6:9d:49:71:31:42:92:c6:
        02:20:25:c1:6d:fd:8c:1f:4a:05:5c:a2:6e:12:5e:4e:52:16:
        88:90:c6:9e:6b:58:97:8e:94:56:36:e7:75:6a:d8:50
```

</details>

### Platform Certificates:

* `scripts/config` contains configuration-file subdirectories corresponding to versions of [TCG Platform Certificate Profile](https://trustedcomputinggroup.org/resource/tcg-platform-certificate-profile/). These configuration files are used by PACCOR when running `create_platform_certs.sh`.
* Each Platform Certificate has a unique certificate serial number, assigned through PACCOR's `--serial` option, starting at 20 and incrementing by 1 for each certificate that is created.
* Certificates that describe the same physical platform use the same Platform Serial Number in the Platform Certificate attributes. Therefore, a Delta Platform Certificate uses the same Platform Serial Number as the Base Platform Certificate it references, while retaining its own unique certificate serial number.
* Delta Platform Certs has 2 configuration files:
  * 1 config that reflects changed fields, which Paccor uses to create the Delta Platform Cert (such as [ComponentList_PCUseCase2.json](config/platform_certs_v1.1/ComponentList_PCUseCase2.json))
  * 1 config that reflects final state of the platform after changes, which Paccor uses to validate the Delta Platform Cert (such as [ComponentList_PCUseCase2_FinalState.json](config/platform_certs_v1.1/ComponentList_PCUseCase2_FinalState.json))
