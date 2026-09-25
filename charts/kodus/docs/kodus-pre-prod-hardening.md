# Kodus Pre-Production Hardening Checklist

This checklist is intentionally separate from the pilot deployment work. The
current Kodus deployment is a pilot and must not be considered production-ready
until the relevant sections below are completed and evidenced.

## 1. Environment And Ownership

- [ ] Confirm the production cluster and kubeconfig context.
- [ ] Confirm the production GCP project and region.
- [ ] Confirm the namespace ownership and naming convention.
- [ ] Assign a Kodus service owner.
- [ ] Assign an infrastructure owner.
- [ ] Assign a GitHub App owner.
- [ ] Assign a Bifrost/provider owner.
- [ ] Define the support channel and escalation path.
- [ ] Define the incident commander for Kodus incidents.
- [ ] Record the service criticality and expected support hours.

## 2. Secret Management

- [ ] Confirm SOPS is the approved secret-management path for this deployment.
- [ ] Decide whether Infisical is permanently out of scope or required for production.
- [ ] Store all required Kodus application secrets in the approved encrypted source.
- [ ] Store PostgreSQL credentials in the approved encrypted source.
- [ ] Store MongoDB credentials in the approved encrypted source.
- [ ] Store RabbitMQ credentials in the approved encrypted source.
- [ ] Store the Bifrost virtual key in the approved encrypted source.
- [ ] Store GitHub App client secret in the approved encrypted source.
- [ ] Store the GitHub App private key in the approved encrypted source.
- [ ] Store GitHub OAuth credentials separately from the GitHub App credentials.
- [ ] Confirm `API_CRYPTO_KEY` has exactly 64 hexadecimal characters.
- [ ] Confirm `CODE_MANAGEMENT_SECRET` has exactly 64 hexadecimal characters.
- [ ] Confirm `WEB_NEXTAUTH_SECRET` and `NEXTAUTH_SECRET` are identical.
- [ ] Confirm no secret is rendered into a ConfigMap.
- [ ] Define secret rotation ownership.
- [ ] Test application secret rotation in a non-production namespace.
- [ ] Document the rollout required after secret rotation.
- [ ] Document emergency revocation and replacement of GitHub credentials.
- [ ] Document Bifrost key rotation and rollback.

## 3. GitHub App And OAuth

- [ ] Verify whether the existing GitHub App can be reused.
- [ ] Confirm the existing App ID.
- [ ] Confirm the existing App installation and repository scope.
- [ ] Confirm Contents read-only permission.
- [ ] Confirm Pull requests read/write permission.
- [ ] Confirm Issues read/write permission where required.
- [ ] Confirm Checks read/write permission where required.
- [ ] Confirm Metadata read-only permission.
- [ ] Enable Pull request webhook events.
- [ ] Enable Pull request review comment webhook events.
- [ ] Enable Issue comment webhook events.
- [ ] Enable Push webhook events.
- [ ] Confirm the App webhook is active.
- [ ] Configure the public webhook URL.
- [ ] Confirm the GitHub App callback URL.
- [ ] Confirm the GitHub App setup URL.
- [ ] Confirm Redirect on update is enabled where applicable.
- [ ] Install the App on one pilot repository.
- [ ] Confirm the App does not interfere with Argo CD usage.
- [ ] Decide whether a separate GitHub OAuth App is required.
- [ ] Configure the OAuth callback URL if sign-in with GitHub is enabled.
- [ ] Record App ownership and renewal/revocation procedures.

## 4. Network And Exposure

- [ ] Confirm the Kodus web UI is Tailscale-only.
- [ ] Confirm the Kodus API is Tailscale-only.
- [ ] Confirm PostgreSQL is cluster-internal only.
- [ ] Confirm MongoDB is cluster-internal only.
- [ ] Confirm RabbitMQ is cluster-internal only.
- [ ] Confirm only the webhook hostname is public.
- [ ] Create or verify DNS for `kodus-webhooks.iplan.dados.rio`.
- [ ] Confirm DNS points to the intended Istio ingress.
- [ ] Confirm the TLS certificate covers the webhook hostname.
- [ ] Confirm the certificate is trusted by external GitHub delivery.
- [ ] Verify the webhook path is exactly `/github/webhook`.
- [ ] Confirm no `/api` or `/webhooks` prefix is introduced.
- [ ] Confirm the public route cannot reach the web UI service.
- [ ] Confirm the public route cannot reach the API service.
- [ ] Restrict NetworkPolicy ingress to approved sources.
- [ ] Review NetworkPolicy egress from API and worker pods.
- [ ] Confirm worker pods can reach Bifrost.
- [ ] Confirm worker pods cannot reach unintended external services.
- [ ] Review service-account permissions.
- [ ] Confirm Pod Security Standards or equivalent enforcement.

## 5. Datastore Resilience

- [ ] Decide whether PostgreSQL remains bundled for the pilot only.
- [ ] Decide whether MongoDB remains bundled for the pilot only.
- [ ] Decide whether RabbitMQ remains bundled for the pilot only.
- [ ] Select managed or operator-backed PostgreSQL for production.
- [ ] Select managed or operator-backed MongoDB for production.
- [ ] Select managed or operator-backed RabbitMQ for production.
- [ ] Confirm PostgreSQL pgvector availability in the production target.
- [ ] Confirm MongoDB authentication uses the correct admin authentication source.
- [ ] Confirm RabbitMQ delayed-message plugin availability.
- [ ] Confirm `kodus-ai` vhost exists.
- [ ] Confirm `kodus-ast` vhost exists where required.
- [ ] Confirm RabbitMQ permissions for the Kodus user.
- [ ] Confirm StorageClass and volume binding behavior.
- [ ] Confirm PVC capacity and expansion support.
- [ ] Define PostgreSQL backup schedule.
- [ ] Define MongoDB backup schedule.
- [ ] Define RabbitMQ persistence and recovery behavior.
- [ ] Define backup retention periods.
- [ ] Perform a PostgreSQL restore test.
- [ ] Perform a MongoDB restore test.
- [ ] Perform a RabbitMQ recovery test.
- [ ] Document recovery point and recovery time objectives.

## 6. Resources And Scaling

- [ ] Review PostgreSQL resource requests and limits after pilot usage.
- [ ] Review MongoDB resource requests and limits after pilot usage.
- [ ] Review RabbitMQ resource requests and limits after pilot usage.
- [ ] Review application pod resource requests and limits.
- [ ] Confirm node capacity for all requests.
- [ ] Confirm namespace quotas allow peak replicas.
- [ ] Confirm PostgreSQL connection limits match application replicas.
- [ ] Define minimum and maximum API replicas.
- [ ] Define minimum and maximum worker replicas.
- [ ] Define minimum and maximum webhook replicas.
- [ ] Define HPA metrics and thresholds.
- [ ] Enable HPA only after metrics are available.
- [ ] Enable PDB only when replica counts make it safe.
- [ ] Test worker behavior during scale-up.
- [ ] Test worker behavior during scale-down.
- [ ] Test node drain behavior.
- [ ] Test rolling restart behavior.

## 7. Observability And Alerting

- [ ] Centralize API logs.
- [ ] Centralize worker logs.
- [ ] Centralize webhook logs.
- [ ] Centralize migration logs.
- [ ] Monitor API health endpoints.
- [ ] Monitor webhook delivery failures.
- [ ] Monitor RabbitMQ queue depth.
- [ ] Monitor worker failures and retries.
- [ ] Monitor PostgreSQL availability.
- [ ] Monitor MongoDB availability.
- [ ] Monitor PVC usage.
- [ ] Monitor pod restarts and OOMKills.
- [ ] Monitor Bifrost latency and error rates.
- [ ] Monitor GitHub API rate limits.
- [ ] Alert on failed migration Jobs.
- [ ] Alert on a growing review queue.
- [ ] Alert on webhook endpoint failure.
- [ ] Alert on provider authentication failure.
- [ ] Define dashboard ownership.
- [ ] Define alert severity and escalation.

## 8. Upgrade And Rollback

- [ ] Pin the Kodus chart version.
- [ ] Pin the Kodus application image version.
- [ ] Pin datastore chart versions.
- [ ] Review Kodus release notes before upgrades.
- [ ] Render the proposed chart version before upgrading.
- [ ] Run Helm lint and unit tests before upgrading.
- [ ] Create a fresh OpenTofu plan before upgrading.
- [ ] Back up databases before migrations.
- [ ] Verify migration Job behavior on upgrade.
- [ ] Define application rollback procedure.
- [ ] Define datastore rollback/recovery procedure.
- [ ] Define secret rollback procedure.
- [ ] Define Bifrost model rollback procedure.
- [ ] Document that Helm rollback does not reverse database migrations.
- [ ] Perform a rollback rehearsal in a non-production namespace.
- [ ] Document upgrade approval authority.

## 9. Runtime Acceptance

- [ ] Verify all application Pods become Ready.
- [ ] Verify the migration Job completes successfully.
- [ ] Verify all PVCs are Bound.
- [ ] Verify Services and EndpointSlices.
- [ ] Verify Tailscale web access.
- [ ] Verify Tailscale API access.
- [ ] Verify public webhook TLS.
- [ ] Verify GitHub webhook delivery.
- [ ] Verify Kodus receives the webhook.
- [ ] Verify RabbitMQ queues receive review work.
- [ ] Verify the worker processes review work.
- [ ] Verify Bifrost accepts the configured model request.
- [ ] Verify Kodus posts a review to GitHub.
- [ ] Test a compliant pull request.
- [ ] Test a deliberately non-compliant pull request.
- [ ] Record review latency.
- [ ] Record useful findings.
- [ ] Record false positives.
- [ ] Record duplicate comments.
- [ ] Record failed and retried reviews.

## 10. Review Policy And Governance

- [ ] Start with advisory-only reviews.
- [ ] Define the quality owner.
- [ ] Define the repository owner.
- [ ] Define the exception owner.
- [ ] Define false-positive escalation.
- [ ] Define whether Kodus can block merges.
- [ ] Define whether blocking differs by repository.
- [ ] Define required branch-protection checks.
- [ ] Define the approval process for changing policy.
- [ ] Measure pilot usefulness before enabling blocking.
- [ ] Document the final policy in the quality-gate documentation.

## 11. Operational Documentation

- [ ] Document service ownership.
- [ ] Document deployment and upgrade commands.
- [ ] Document webhook troubleshooting.
- [ ] Document GitHub App troubleshooting.
- [ ] Document Bifrost troubleshooting.
- [ ] Document queue and worker troubleshooting.
- [ ] Document secret rotation.
- [ ] Document backup and restore.
- [ ] Document rollback limitations.
- [ ] Document incident response.
- [ ] Document maintenance windows.
- [ ] Document model changes and approval.
- [ ] Link this checklist from the Kodus deployment plan.

## Exit Criteria

- [ ] All high-priority security and secret-management items are complete.
- [ ] Backups and restore tests are complete.
- [ ] Monitoring and alerting are active.
- [ ] GitHub integration is validated.
- [ ] Bifrost integration is validated.
- [ ] Runtime acceptance tests are recorded.
- [ ] Ownership and escalation are documented.
- [ ] Review policy is approved.
- [ ] Production deployment approval is recorded.
