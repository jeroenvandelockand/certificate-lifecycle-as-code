# Certificate lifecycle

## Issuance

1. Argo CD applies the demo `Certificate`.
2. cert-manager creates a `CertificateRequest`.
3. approver-policy selects the request by namespace and issuer.
4. RBAC allows the cert-manager controller ServiceAccount to use the policy.
5. The allowed DNS name, duration, usage and RSA key constraints are evaluated.
6. The request is approved and sent to the `demo-ca` `ClusterIssuer`.
7. cert-manager writes `tls.crt`, `tls.key` and `ca.crt` into `demo-app-tls`.
8. nginx mounts the Secret and serves TLS on port 8443.

## Denial

The forbidden scenario asks for `banking.example.com`. The policy only permits
`*.apps.demo.internal`, so the request receives a permanent `Denied=True`
condition and no Secret is issued.

## Renewal and key rotation

The lab certificate lifetime is one hour and `renewBeforePercentage` is 90.
This deliberately moves renewal into a demo-friendly window of roughly six
minutes. `rotationPolicy: Always` instructs cert-manager to create a new private
key for the renewed certificate.

`make test-renewal` records both certificate serial and public-key fingerprint,
then waits until both values change.

These timings are for the lab only. Production duration and renewal windows
must match PKI policy, outage tolerance and CA capacity.

## Consumption caveat

Kubernetes updates mounted Secret volumes, but a process is not guaranteed to
reload changed key material. The V1 nginx workload proves initial consumption.
Automatic application reload is a separate V1.1 concern; ingress controllers
and applications must each be tested for their actual reload behavior.

