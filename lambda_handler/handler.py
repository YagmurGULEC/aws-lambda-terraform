import numpy as np

def lambda_handler(event, context):
    A = np.array([[1, 2], [3, 4]])
    B = np.array([[5, 6], [7, 8]])
    return {"statusCode": 200, "body": np.dot(A, B).tolist()}