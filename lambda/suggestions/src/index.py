import json
import boto3
import os
from datetime import datetime

s3 = boto3.client("s3")
sns = boto3.client("sns")
BUCKET = os.environ["BUCKET_NAME"]
SNS_TOPIC = os.environ.get("SNS_TOPIC_ARN", "")


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")

    if method == "OPTIONS":
        return {"statusCode": 204, "headers": _cors()}

    if method != "POST":
        return _resp(405, {"error": "Method not allowed"})

    try:
        body = json.loads(event.get("body", "{}"))
        name = body.get("name", "").strip()
        review = body.get("review", "").strip()
        categories = body.get("categories", [])

        if not name or not review:
            return _resp(400, {"error": "Nom et avis sont requis."})

        ts = datetime.utcnow()
        key = f"suggestions/{ts.strftime('%Y%m%d_%H%M%S')}_{name.replace(' ', '_')}.json"

        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(
                {
                    "name": name,
                    "review": review,
                    "categories": categories,
                    "submitted_at": ts.isoformat() + "Z",
                },
                ensure_ascii=False,
            ),
            ContentType="application/json",
        )

        if SNS_TOPIC:
            cats_str = ", ".join(categories) if categories else "Aucune"
            sns.publish(
                TopicArn=SNS_TOPIC,
                Subject=f"El Routardo - Nouvelle suggestion de {name}",
                Message=(
                    f"Nouvelle suggestion reçue !\n\n"
                    f"Nom : {name}\n"
                    f"Catégories : {cats_str}\n\n"
                    f"Suggestion :\n{review}\n\n"
                    f"---\n"
                    f"Soumise le {ts.strftime('%d/%m/%Y à %H:%M')} UTC"
                ),
            )

        return _resp(200, {"message": "Merci pour votre suggestion !"})

    except json.JSONDecodeError:
        return _resp(400, {"error": "JSON invalide."})
    except Exception as e:
        print(f"Error: {e}")
        return _resp(500, {"error": "Erreur interne."})


def _cors():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {**_cors(), "Content-Type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False),
    }
