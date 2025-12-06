{
  "subject": {
    "commonName": "${INTERMEDIATE_CA_NAME}",
    "organizationName": "${CA_ORG_NAME}",
    "countryName": "${CA_COUNTRY_NAME}",
    "localityName": "${CA_LOCALITY_NAME}"
  },
  "keyUsage": [ "certSign", "crlSign" ],
  "basicConstraints": {
    "isCA": true,
    "maxPathLen": 1
  }
}