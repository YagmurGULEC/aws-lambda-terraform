import json, os, time, uuid, boto3,decimal

dynamodb = boto3.resource("dynamodb") 
table = dynamodb.Table(os.environ["JOB_TABLE"]) 
sqs = boto3.client("sqs") 
QUEUE_URL = os.environ["QUEUE_URL"]
def convert_decimals(obj):
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, decimal.Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj

def _resp(code, body):
    return {"statusCode": code, "headers":{"Content-Type":"application/json","Access-Control-Allow-Origin":"*"}, "body": json.dumps(body)}
def create_job(event):
    body = json.loads(event.get("body") or "{}")
    job_id = body.get("job_id") or str(uuid.uuid4())
    now = int(time.time())
    # 1) write queued status
    table.put_item(Item={"job_id": job_id, "status": "queued", "created_at": now, "updated_at": now})
    # 2) enqueue
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({"job_id": job_id, "params": body.get("params")}),
        # For FIFO queues uncomment:
        # MessageGroupId="jobs",
        # MessageDeduplicationId=job_id,
    )
    return _resp(201, {"job_id": job_id, "status": "queued"})

def get_job_status(event):
    job_id = (event.get("pathParameters") or {}).get("id") or (event.get("queryStringParameters") or {}).get("id")
    if not job_id:
        return _resp(400, {"error": "missing job_id"})
    res = table.get_item(Key={"job_id": job_id})
    item = res.get("Item")
    if not item:
        return _resp(404, {"error": "not found"})
    # Convert any Decimal values before returning
    clean_item = convert_decimals(item)
    return _resp(200, clean_item)

def unified_api_handler(event, context):
    m = event.get("requestContext", {}).get("http", {}).get("method") or event.get("httpMethod")
    raw_path = event.get("rawPath", "")
    stage = event.get("requestContext", {}).get("stage", "")
    p = raw_path[len(f"/{stage}"):] if raw_path.startswith(f"/{stage}") else raw_path

    print("Method:", m)
    print("Path:", p)

    if m == "OPTIONS":
        return _resp(204, {})

    if m == "POST" and p == "/jobs":
        return create_job(event)

    if m == "GET" and p.startswith("/jobs"):
        return get_job_status(event)

    return _resp(404, {"error": "not found"})