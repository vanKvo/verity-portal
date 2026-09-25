# Local backend S3 pull fails with InvalidClientTokenId

**Date:** 2026-09-24
**Environment:** dev, local backend (FastAPI run outside Lambda)

## Symptom

Running the backend locally and pulling a file from `verity-portal-dev-ingest-bucket`
(via the S3 ingest webhook flow) failed with an AWS `InvalidClientTokenId` /
"The security token included in the request is invalid" error, even though:
- `terraform apply` against the same AWS account succeeded locally.
- `aws s3 ls` / `head-object` / `list-objects-v2` against the same bucket succeeded locally.
- The Terraform IAM policy for the backend Lambda's role already grants
  `s3:GetObject`/`ListBucket`/`PutObject`/`DeleteObject` on the bucket
  (`terraform/modules/core_infrastructure/main.tf:184-196`).

## Investigation

Traced the S3 client construction in `backend/src/verity_portal/data_hub/core/retrieval.py`
back to `Settings.aws_credential_kwargs()` in `backend/src/verity_portal/core/config.py`.
That method injected explicit `aws_access_key_id`/`aws_secret_access_key` kwargs into
`boto3.client()` whenever running outside Lambda and `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
were set in `.env`.

On inspection, `backend/.env` actually had these set to **empty strings**
(`AWS_ACCESS_KEY_ID=""`, `AWS_SECRET_ACCESS_KEY=""`), which are falsy in the method's
`if self.AWS_ACCESS_KEY_ID and self.AWS_SECRET_ACCESS_KEY:` check — so the override
branch was not actually firing from this file, and boto3 was already falling back to
its default credential chain (the local `~/.aws/credentials [default]` profile) for
this specific case.

**Conclusion:** the override mechanism was dead code given the current `.env`, but it
was a latent footgun — any future non-empty (and possibly stale) value written to
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in `.env` would silently override a working
default-credential-chain setup and reproduce this exact failure. The likely actual
trigger for what was observed is a stale `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
exported as a real shell environment variable (e.g. from a past `export` left in a
terminal session or shell profile), which boto3's credential chain checks *before*
`~/.aws/credentials`, and which is invisible to `.env`/pydantic-settings.

## Fix

Removed the static-credential-override mechanism entirely so boto3 always resolves
credentials via its default chain (local `[default]` profile outside Lambda, IAM
execution role inside Lambda) — matching what `terraform apply` and the `aws` CLI
already do successfully in this environment:

- `backend/src/verity_portal/core/config.py`: removed `AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY` settings fields and the `aws_credential_kwargs()` method.
- `backend/src/verity_portal/data_hub/core/retrieval.py`: dropped
  `**settings.aws_credential_kwargs()` from the S3 client construction.
- `backend/src/verity_portal/core/email.py`: dropped the same kwarg spread from the
  SNS client construction.
- `backend/.env`: removed the now-unused empty `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
  lines; renamed `AWS_DEFAULT_REGION` to `AWS_REGION` to match what `Settings` actually
  reads.

Verified with `poetry run pytest tests/data_hub/test_retrieval.py` (9 passed).

## Remaining action for whoever hits this

If `InvalidClientTokenId` still occurs locally after this fix, check for stray AWS
credential env vars shadowing the default profile in the terminal running the backend:

```bash
env | grep AWS
```

If `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` are set there,
`unset` them (or remove the `export` from the shell profile) so boto3 falls through to
`~/.aws/credentials [default]`.
