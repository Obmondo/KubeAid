kind: StatefulSet
replicaCount: 1
autocert:
  enabled: false
bootstrap:
  enabled: false
ca:
  db:
      enabled: true
      persistent: false
inject:
  enabled: true
  config:
    files:
      ca.json:
        root: /home/step/certs/root_ca.crt
        federateRoots: []
        crt: /home/step/certs/intermediate_ca.crt
        key: /home/step/secrets/intermediate_ca_key
        address: 0.0.0.0:9000
        dnsNames: ${CA_DNS_NAMES}
        logger:
          format: json
        db:
          type: badgerv2
          dataSource: /home/step/db
        authority:
          claims:
            minTLSCertDuration: 5m
            maxTLSCertDuration: 24h
            defaultTLSCertDuration: 24h
            disableRenewal: false
            minHostSSHCertDuration: 5m
            maxHostSSHCertDuration: 1680h
            defaultHostSSHCertDuration: 720h
            minUserSSHCertDuration: 5m
            maxUserSSHCertDuration: 24h
            defaultUserSSHCertDuration: 24h
          provisioners:
            - type: ACME
              name: acme
              forceCN: true
              claims: {}
            - type: SSHPOP
              name: sshpop
              claims:
                enableSSHCA: true
            - type: JWK
              name: ${JWK_PROVISIONER_NAME}
              key: 
                alg: "${JWK_PROVISIONER_CRT_ALG}"
                crv: "${JWK_PROVISIONER_CRT_CRV}"
                kid: "${JWK_PROVISIONER_CRT_KID}"
                kty: "${JWK_PROVISIONER_CRT_KTY}"
                use: "${JWK_PROVISIONER_CRT_USE}"
                x: "${JWK_PROVISIONER_CRT_X}"
                'y': "${JWK_PROVISIONER_CRT_Y}"
              encryptedKey: "${JWK_PROVISIONER_KEY}"
              claims:
                enableSSHCA: true
        tls:
          cipherSuites:
            - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
            - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
            - TLS_AES_128_GCM_SHA256
          minVersion: 1.2
          maxVersion: 1.3
          renegotiation: false
      defaults.json:
        ca-url: ${CA_URL}
        ca-config: /home/step/config/ca.json
        fingerprint: ${TLS_ROOT_FINGERPRINT}
        root: /home/step/certs/root_ca.crt
    templates:
      x509_leaf.tpl: |
        {
          "subject": {{ toJson .Subject }},
          "sans": {{ toJson .SANs }},
        {{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
          "keyUsage": ["keyEncipherment", "digitalSignature"],
        {{- else }}
          "keyUsage": ["digitalSignature"],
        {{- end }}
          "extKeyUsage": ["serverAuth", "clientAuth"]
        }
      ssh.tpl: |
        {
          "type": {{ toJson .Type }},
          "keyId": {{ toJson .KeyID }},
          "principals": {{ toJson .Principals }},
          "extensions": {{ toJson .Extensions }},
          "criticalOptions": {{ toJson .CriticalOptions }}
        }
  certificates:
    intermediate_ca: |
${TLS_INTERMEDIATE_CRT}
    root_ca: |
${TLS_ROOT_CRT}
    ssh_host_ca: "${SSH_HOST_CRT}"
    ssh_user_ca: "${SSH_USER_CRT}"
  secrets:
    ca_password: "${INTERMEDIATE_TLS_PASSWORD_B64}"
    provisioner_password: "${JWK_PROVISIONER_PASSWORD_B64}"
    certificate_issuer:
      enabled: false
    x509:
      enabled: true
      intermediate_ca_key: |
${TLS_INTERMEDIATE_KEY}
      root_ca_key: |
${TLS_ROOT_KEY}
    ssh:
      enabled: true
      host_ca_key: |
${SSH_HOST_KEY}
      host_ca_password: "${SSH_HOST_PASSWORD_B64}"
      user_ca_key: |
${SSH_USER_KEY}
      user_ca_password: "${SSH_USER_PASSWORD_B64}"
service:
  type: ClusterIP
  port: 443
  targetPort: 9000
  nodePort: 32400
ingress:
  enabled: false
  annotations: {}
  hosts: []
  tls: []

