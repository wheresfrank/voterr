#!/bin/sh
# Disable the eMudhra G3 hierarchies and the retired AAA cross-signing root.
# Incident: https://bugzilla.mozilla.org/show_bug.cgi?id=2083449
# Fingerprints: https://repository.emsign.com/ and Mozilla's historical root store.
# Run before update-ca-certificates --fresh. No network access is required.
set -eu

root=${1:-/}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
: > "$work/disabled"

for dir in "$root/usr/share/ca-certificates" "$root/usr/local/share/ca-certificates"; do
    [ ! -d "$dir" ] || find "$dir" -type f -name '*.crt' >> "$work/files"
done
[ -f "$work/files" ] || { echo "No CA source directories found" >&2; exit 1; }

while IFS= read -r cert; do
    # Do not hide openssl errors behind a pipeline: a corrupt CA must fail the build.
    fingerprint=$(openssl x509 -in "$cert" -noout -sha256 -fingerprint)
    fingerprint=$(printf '%s' "$fingerprint" | cut -d= -f2 | tr -d ':' | tr 'A-F' 'a-f')
    case "$fingerprint" in
        # emSign ECC G3, TLS G3 (both variants), and AAA Certificate Services.
        86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b|\
        7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d|\
        3094025792039a68af6e553686410bdab7c0d4a36b9084cba64202e35d6ebbdd|\
        d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4)
            relative=${cert#"$root/usr/share/ca-certificates/"}
            printf '%s\n' "$relative" >> "$work/disabled"
            # Keep the public cert for inspection, outside the *.crt import glob.
            mv "$cert" "$cert.distrusted"
            echo "Distrusted CA: $fingerprint" >&2
            ;;
    esac
done < "$work/files"

conf="$root/etc/ca-certificates.conf"
if [ -f "$conf" ]; then
    awk 'FILENAME == ARGV[1] { blocked[$0] = 1; next }
         { if ($0 in blocked) print "!" $0; else print }' \
        "$work/disabled" "$conf" > "$work/config"
    cat "$work/config" > "$conf"
fi
