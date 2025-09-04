import os
import json
import datetime
import boto3
from botocore.exceptions import ClientError

TABLE_NAME = os.environ.get("TABLE_NAME", "test-user-access")
ROLE_TEMPLATE = os.environ.get("ROLE_TEMPLATE", "{userid}-role")

ddb = boto3.resource("dynamodb").Table(TABLE_NAME)
iam = boto3.client("iam")


def _iso_utc_now():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _bool_param(val, default=False):
    if val is None:
        return default
    if isinstance(val, bool):
        return val
    s = str(val).strip().lower()
    return s in ("1", "true", "t", "yes", "y")


def _get_user_record(userid: str):
    resp = ddb.get_item(Key={"userid": userid}, ConsistentRead=True)
    return resp.get("Item")


def _list_attached_policy_arns(role_name: str):
    arns = set()
    paginator = iam.get_paginator("list_attached_role_policies")
    for page in paginator.paginate(RoleName=role_name):
        for p in page.get("AttachedPolicies", []):
            arns.add(p["PolicyArn"])
    return arns


def _detach_policies(role_name: str, to_detach: set, dry_run: bool):
    results = []
    for arn in sorted(to_detach):
        if dry_run:
            results.append(f"DRY_RUN:{arn}")
            continue
        try:
            iam.detach_role_policy(RoleName=role_name, PolicyArn=arn)
            results.append(arn)
        except ClientError as e:
            code = e.response.get("Error", {}).get("Code", "Unknown")
            results.append(f"ERROR:{arn}:{code}")
    return results


def _ok(body: dict, code: int = 200):
    return {
        "statusCode": code,
        "body": json.dumps(body),
        "headers": {"Content-Type": "application/json"},
    }


def _err(msg: str, code: int = 400):
    return _ok({"error": msg}, code)


def lambda_handler(event, context):
    try:
        qs = (event or {}).get("queryStringParameters") or {}
        userid = (qs.get("userid") or "").strip()
        if not userid:
            return _err("missing userid (use /user-access?userid=<id>&dry_run=true|false)", 400)
        dry_run = _bool_param(qs.get("dry_run"), default=False)

        # 1) Load user record from DynamoDB
        item = _get_user_record(userid)
        if not item:
            return _err("userid not found in DynamoDB", 404)

        required_list = item.get("required_policies") or []
        if not isinstance(required_list, list) or not all(isinstance(x, str) for x in required_list):
            return _err("DynamoDB item must contain required_policies as List<String>", 500)
        required = set(required_list)

        role_name = item.get("role_name") or ROLE_TEMPLATE.format(userid=userid)
        if not role_name:
            return _err("role_name missing and ROLE_TEMPLATE not set", 500)

        # 2) Read currently attached policies
        attached = _list_attached_policy_arns(role_name)

        # 3) Diff
        to_detach = attached - required
        kept = attached & required

        # 4) Act
        detached = _detach_policies(role_name, to_detach, dry_run)

        # 5) Persist run summary (best-effort)
        try:
            ddb.update_item(
                Key={"userid": userid},
                UpdateExpression=(
                    "SET last_run_ts=:ts, last_request=:rq, last_attached_before=:ab, "
                    "last_detached=:dt, last_kept=:kp"
                ),
                ExpressionAttributeValues={
                    ":ts": _iso_utc_now(),
                    ":rq": {"dry_run": dry_run},
                    ":ab": sorted(list(attached)),
                    ":dt": sorted(list(detached)),
                    ":kp": sorted(list(kept)),
                },
            )
        except ClientError:
            pass  # non-fatal

        return _ok({
            "userid": userid,
            "role_name": role_name,
            "required": sorted(list(required)),
            "attached_before": sorted(list(attached)),
            "detached_now": sorted(list(detached)),
            "kept": sorted(list(kept)),
            "dry_run": dry_run,
            "message": "unrequired policies detached" if not dry_run else "dry-run: nothing detached"
        })

    except Exception as e:
        return _err(f"internal error: {str(e)}", 500)
