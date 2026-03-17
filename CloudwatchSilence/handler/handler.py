# # handler.py
# import os
# import time
# import boto3  
# from botocore.config import Config 

# MAX_PER_CALL = 100

# def _env(name, default=None):
#     v = os.environ.get(name)
#     return v if v is not None else default

# def lambda_handler(event, context):
#     action = (event.get("action") or "").upper()
#     if action not in ("MUTE", "UNMUTE"):
#         raise ValueError(f"Invalid action: {action}. Use MUTE or UNMUTE.")

#     filter_mode  = _env("FILTER_MODE", "TAGS").upper()  # TAGS | PREFIX | ALL
#     tag_key      = _env("TAG_KEY", "Mute")
#     tag_value    = _env("TAG_VALUE", "true")
#     alarm_prefix = _env("ALARM_PREFIX", "")
#     batch_size   = min(int(_env("BATCH_SIZE", "100")), MAX_PER_CALL)
#     regions_csv  = _env("REGIONS", "")
#     dry_run      = _env("DRY_RUN", "false").lower() == "true"

#     regions = [r.strip() for r in regions_csv.split(",") if r.strip()] or [os.environ.get("AWS_REGION")]

#     total_found  = 0
#     total_changed = 0
#     total_calls  = 0

#     cfg = Config(retries={"max_attempts": 8, "mode": "standard"},
#                  user_agent_extra="mute-alarms-lambda/1.0")

#     account_id = boto3.client("sts").get_caller_identity()["Account"]

#     for region in regions:
#         cw = boto3.client("cloudwatch", region_name=region, config=cfg)

#         if filter_mode == "PREFIX" and alarm_prefix:
#             paginator = cw.get_paginator("describe_alarms")
#             pages = paginator.paginate(AlarmNamePrefix=alarm_prefix)
#         else:
#             paginator = cw.get_paginator("describe_alarms")
#             pages = paginator.paginate()

#         pending = []

#         for page in pages:
#             alarms = page.get("MetricAlarms", []) + page.get("CompositeAlarms", [])
#             for a in alarms:
#                 name = a["AlarmName"]
#                 total_found += 1

#                 # Filtrado por TAGS
#                 if filter_mode == "TAGS":
#                     arn = f"arn:aws:cloudwatch:{region}:{account_id}:alarm:{name}"
#                     try:
#                         tags = cw.list_tags_for_resource(ResourceARN=arn).get("Tags", [])
#                         if not any(t.get("Key") == tag_key and str(t.get("Value")).lower() == str(tag_value).lower() for t in tags):
#                             continue
#                     except Exception as e:
#                         print(f"[WARN] list_tags_for_resource failed for {arn}: {e}")
#                         continue
#                 elif filter_mode == "PREFIX" and alarm_prefix:
#                     if not name.startswith(alarm_prefix):
#                         continue
#                 # ALL = sin filtro

#                 actions_enabled = a.get("ActionsEnabled", True)
#                 if action == "MUTE" and not actions_enabled:
#                     continue  # ya está muteada
#                 if action == "UNMUTE" and actions_enabled:
#                     continue  # ya está habilitada

#                 pending.append(name)
#                 if len(pending) >= batch_size:
#                     _apply(cw, action, pending, dry_run)
#                     total_calls += 1
#                     total_changed += len(pending)
#                     pending = []

#         if pending:
#             _apply(cw, action, pending, dry_run)
#             total_calls += 1
#             total_changed += len(pending)

#     result = {
#         "action": action,
#         "found": total_found,
#         "changed": total_changed,
#         "api_calls": total_calls,
#         "regions": regions,
#         "filter_mode": filter_mode,
#         "dry_run": dry_run,
#     }
#     print(result)
#     return result


# def _apply(cw, action, names, dry_run):
#     if dry_run:
#         print(f"[DRY_RUN] {action} {len(names)} alarms. Sample: {names[:5]}")
#         return

#     backoff = 1.0
#     for attempt in range(1, 6):
#         try:
#             if action == "MUTE":
#                 cw.disable_alarm_actions(AlarmNames=names)
#             else:
#                 cw.enable_alarm_actions(AlarmNames=names)
#             print(f"[OK] {action} batch size={len(names)}")
#             return
#         except cw.exceptions.LimitExceededFault as e:
#             print(f"[Retry] LimitExceeded attempt={attempt}: {e}")
#         except Exception as e:
#             # throttling u otros transitorios
#             se = str(e)
#             if "Throttl" in se or "Rate exceeded" in se:
#                 print(f"[Retry] Throttling attempt={attempt}: {e}")
#             else:
#                 print(f"[ERROR] {action} failed: {e}")
#                 raise
#         time.sleep(backoff)
#         backoff = min(backoff * 2, 10.0)

###Correccion:
# handler.py
import os
import time
import boto3
from botocore.config import Config

MAX_PER_CALL = 100


def _env(name, default=None):
    v = os.environ.get(name)
    return v if v is not None else default


def lambda_handler(event, context):
    # -------------------------
    # Acción (MUTE / UNMUTE)
    # -------------------------
    action = (event.get("action") or "").upper()
    if action not in ("MUTE", "UNMUTE"):
        raise ValueError(f"Invalid action: {action}. Use MUTE or UNMUTE.")

    # -------------------------
    # Variables de entorno
    # -------------------------
    filter_mode  = _env("FILTER_MODE", "TAGS").upper()   # TAGS | PREFIX | ALL
    tag_key      = _env("TAG_KEY", "Mute").lower()       # ✅ normalizado
    tag_value    = _env("TAG_VALUE", "true").lower()     # ✅ normalizado
    alarm_prefix = _env("ALARM_PREFIX", "")
    batch_size   = min(int(_env("BATCH_SIZE", "100")), MAX_PER_CALL)
    regions_csv  = _env("REGIONS", "")
    dry_run      = _env("DRY_RUN", "false").lower() == "true"

    regions = [r.strip() for r in regions_csv.split(",") if r.strip()] or [
        os.environ.get("AWS_REGION")
    ]

    total_found   = 0
    total_changed = 0
    total_calls   = 0

    cfg = Config(
        retries={"max_attempts": 8, "mode": "standard"},
        user_agent_extra="mute-alarms-lambda/1.0",
    )

    account_id = boto3.client("sts").get_caller_identity()["Account"]

    # -------------------------
    # Procesar por región
    # -------------------------
    for region in regions:
        cw = boto3.client("cloudwatch", region_name=region, config=cfg)

        paginator = cw.get_paginator("describe_alarms")
        if filter_mode == "PREFIX" and alarm_prefix:
            pages = paginator.paginate(AlarmNamePrefix=alarm_prefix)
        else:
            pages = paginator.paginate()

        pending = []

        for page in pages:
            alarms = page.get("MetricAlarms", []) + page.get("CompositeAlarms", [])

            for a in alarms:
                name = a["AlarmName"]
                total_found += 1

                # ---------------------------------------------------
                # ✅ FILTRO POR TAGS (CASE-INSENSITIVE)
                # ---------------------------------------------------
                if filter_mode == "TAGS":
                    arn = f"arn:aws:cloudwatch:{region}:{account_id}:alarm:{name}"
                    try:
                        tags = cw.list_tags_for_resource(
                            ResourceARN=arn
                        ).get("Tags", [])

                        # Normalizar tags reales
                        normalized_tags = {
                            str(t.get("Key", "")).lower(): str(t.get("Value", "")).lower()
                            for t in tags
                        }

                        if normalized_tags.get(tag_key) != tag_value:
                            continue

                    except Exception as e:
                        print(f"[WARN] list_tags_for_resource failed for {arn}: {e}")
                        continue

                elif filter_mode == "PREFIX" and alarm_prefix:
                    if not name.startswith(alarm_prefix):
                        continue
                # ALL = sin filtro

                # ---------------------------------------------------
                # Estado actual de la alarma
                # ---------------------------------------------------
                actions_enabled = a.get("ActionsEnabled", True)

                if action == "MUTE" and not actions_enabled:
                    continue  # ya está muteada

                if action == "UNMUTE" and actions_enabled:
                    continue  # ya está habilitada

                pending.append(name)

                if len(pending) >= batch_size:
                    _apply(cw, action, pending, dry_run)
                    total_calls += 1
                    total_changed += len(pending)
                    pending = []

        if pending:
            _apply(cw, action, pending, dry_run)
            total_calls += 1
            total_changed += len(pending)

    result = {
        "action": action,
        "found": total_found,
        "changed": total_changed,
        "api_calls": total_calls,
        "regions": regions,
        "filter_mode": filter_mode,
        "dry_run": dry_run,
    }

    print(result)
    return result


def _apply(cw, action, names, dry_run):
    if dry_run:
        print(f"[DRY_RUN] {action} {len(names)} alarms. Sample: {names[:5]}")
        return

    backoff = 1.0

    for attempt in range(1, 6):
        try:
            if action == "MUTE":
                cw.disable_alarm_actions(AlarmNames=names)
            else:
                cw.enable_alarm_actions(AlarmNames=names)

            print(f"[OK] {action} batch size={len(names)}")
            return

        except cw.exceptions.LimitExceededFault as e:
            print(f"[Retry] LimitExceeded attempt={attempt}: {e}")

        except Exception as e:
            se = str(e)
            if "Throttl" in se or "Rate exceeded" in se:
                print(f"[Retry] Throttling attempt={attempt}: {e}")
            else:
                print(f"[ERROR] {action} failed: {e}")
                raise

        time.sleep(backoff)
        backoff = min(backoff * 2, 10.0)