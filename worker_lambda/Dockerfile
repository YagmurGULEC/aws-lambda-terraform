FROM public.ecr.aws/lambda/python:3.12

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install all dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY data_handler.py ${LAMBDA_TASK_ROOT}


# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "data_handler.lambda_handler" ]