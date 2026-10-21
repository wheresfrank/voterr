#!/bin/sh
# Check the actual regenerated bundle AND hashed CA directory in a built image.
set -eu
fixtures=${1:?usage: check-ca-trust.sh fixture-directory}
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt -CApath /etc/ssl/certs "$fixtures/isrg.pem"
for cert in emsign aaa; do
    openssl x509 -in "$fixtures/$cert.pem" -noout >/dev/null
    if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt -CApath /etc/ssl/certs "$fixtures/$cert.pem"; then
        echo "ERROR: blocked $cert anchor is still trusted" >&2
        exit 1
    fi
done
if command -v node >/dev/null 2>&1; then
    node -e 'if (!(process.env.NODE_OPTIONS || "").split(/\s+/).includes("--use-openssl-ca")) throw new Error("Node must use the filtered OpenSSL trust store")'
fi
