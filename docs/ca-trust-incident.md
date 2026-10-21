# October 2026 eMudhra CA incident

The reviewed outbound clients use normal TLS verification: Plex uses Faraday and TMDB uses Net::HTTP. Normal verification
is insufficient when its root store still permits the compromised CA hierarchy.
This change updates trust in images; it does not establish whether any running
deployment was attacked.

The build disables these trust anchors by exact SHA-256 fingerprint:
- emSign ECC Root CA - G3: `86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b`
- emSign Root TLS CA - G3, self-signed: `7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d`
- emSign Root TLS CA - G3, cross-signed: `3094025792039a68af6e553686410bdab7c0d4a36b9084cba64202e35d6ebbdd`
- AAA Certificate Services: `d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4`

AAA is a retired root with an alternate signing path to the compromised
intermediates. Leaving it in an older distro bundle can defeat removal of just
the eMudhra root. Other emSign roots and USERTrust/Sectigo roots are preserved.
Valid sites that still depend on the removed hierarchies can stop connecting;
their operators must move to an unaffected chain. Do not bypass verification.

The script scans distribution and locally imported CA sources, disables matching
configuration entries, and moves blocked certificates outside the *.crt import
glob. `update-ca-certificates --fresh` then regenerates both the bundle and
hashed directory, so clients cannot fall back to an old hashed certificate.
A malformed source certificate fails the build. Re-running is safe.

## Deployment

The shared Ruby base applies distrust before Bundler installs and is inherited
by the final runtime. Rebuild with `docker build --pull --no-cache -t voterr:patched .`
and deploy the resulting image through the normal hosting workflow.

Existing containers do not change when the PR is merged. Rebuild and redeploy.
For native development, update the host/runtime CA store separately. Custom
application CA options, mounted bundles, and trust-related environment overrides
must be audited separately; this build does not rewrite external files.

## Validation

Run `node --test scripts/ca-trust.test.mjs` (Node 22+, OpenSSL on PATH).
Fixtures are public CA certificates with no private keys. Tests cover renamed
and duplicate blocked certificates, local imports, idempotence, preservation of
ISRG Root X1, actual OpenSSL rejection, and failure on corrupt input.
CI also runs `scripts/check-ca-trust.sh` against built image trust stores.
A package vulnerability scan alone does not prove that an application rejects
a compromised chain.

## References

- [Mozilla incident and alternate cross-signs](https://bugzilla.mozilla.org/show_bug.cgi?id=2083449)
- [eMudhra certificate repository and fingerprints](https://repository.emsign.com/)
- [Historical Mozilla-derived AAA certificate fingerprint](https://android.googlesource.com/platform/system/ca-certificates/+/5a9e1c65f159e4a8461bf646aa116001e2844516/google/roots.pem)
