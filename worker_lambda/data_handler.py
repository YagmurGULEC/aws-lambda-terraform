
import os, json, awswrangler as wr
import boto3

dynamo_db = boto3.client("dynamodb")
TABLE_NAME = os.environ["DYNAMO_TABLE"]
GLUE_DATABASE = os.environ["GLUE_DATABASE"]
ATHENA_OUTPUT = os.environ["ATHENA_OUTPUT"]
WORKGROUP     = os.getenv("ATHENA_WORKGROUP", "primary")

athena = boto3.client("athena")

sql_queries = {
    "sql_1": """
        SELECT label,
               COUNT(*) AS instance_count
        FROM annotations_parquet
        GROUP BY label
        ORDER BY instance_count DESC;
    """,
    "sql_2":"""WITH images_per_label AS (
  SELECT DISTINCT label, image_id FROM annotations_parquet
),
ranked AS (
  SELECT
    label, image_id,
    row_number() OVER (
      PARTITION BY label
      ORDER BY mod(crc32(to_utf8(concat(label, ':', image_id, ':seed42'))), 1000000)
    ) AS rn
  FROM images_per_label
),
picked AS (
  SELECT label, image_id FROM ranked WHERE rn <= 500
),
split_assigned AS (
  SELECT
    p.label,
    p.image_id,
    CASE
      WHEN mod(crc32(to_utf8(concat(p.image_id, ':splitseed'))), 100) < 80
        THEN 'train' ELSE 'val'
    END AS split
  FROM picked p
),
final AS ( 
  SELECT a.*, s.split
  FROM annotations_parquet a
  JOIN split_assigned s
    ON a.label = s.label AND a.image_id = s.image_id
)
SELECT
  split,
  label,
  
  COUNT(*) AS objects,
  CAST(COUNT(*) AS DOUBLE)
    / SUM(COUNT(*)) OVER (PARTITION BY split) AS pct_within_split
FROM final
GROUP BY split, label
ORDER BY split, objects DESC;
"""
}
def lambda_handler(event, context):
    res={}
    for record in event["Records"]:
        body = json.loads(record["body"])
        job_id = body["job_id"]
        params=body.get("params", {})
        for param_key, should_run in params.items():
            if should_run=="true" and param_key in sql_queries:
                query=sql_queries[param_key]
                try:
                    df = wr.athena.read_sql_query(
                                query,
                                database=GLUE_DATABASE,
                                ctas_approach=False,
                                s3_output=ATHENA_OUTPUT,
                                workgroup=WORKGROUP,
                            
                            )
                    # Process the DataFrame (df) as needed
                    data=df.to_dict("records")
                    res[param_key]=data
                   
                
                except Exception as e:
                    status="failed"
                    dynamo_db.update_item(
                        TableName=TABLE_NAME,
                        Key={"job_id": {"S": job_id}},
                        UpdateExpression="SET #s = :status",
                        ExpressionAttributeNames={"#s": "status"},
                        ExpressionAttributeValues={":status": {"S": status}}
                    )
                
                    return {"statusCode": 500, "body": str(e)}
    status = "succeeded"
    dynamo_db.update_item(
        TableName=TABLE_NAME,
        Key={"job_id": {"S": job_id}},
        UpdateExpression="SET #s = :status, #r = :result",
        ExpressionAttributeNames={
            "#s": "status",
            "#r": "result"
        },
        ExpressionAttributeValues={
            ":status": {"S": status},
            ":result": {"S": json.dumps(res)}
        }
    )

    return {"statusCode": 200, "body": json.dumps(res)}


    

