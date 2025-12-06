{
  "subject": {
    "commonName": "${INTERMEDIATE_CA_NAME}",
    "organization": "${CA_ORG_NAME}",
    "organizationalUnit": "${CA_ORGUNIT_NAME}",
    "country": "${CA_COUNTRY_NAME}",
    "locality": "${CA_LOCALITY_NAME}"
  },
  "keyUsage": [ "certSign", "crlSign" ],
  "basicConstraints": {
    "isCA": true,
    "maxPathLen": 1
  }
}
