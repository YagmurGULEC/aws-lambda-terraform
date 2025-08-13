#!/bin/bash
set -e

echo "Building numpy layer..."
rm -f function.zip
rm -rf lambda_handler/venv

(
    cd lambda_handler || exit 1
    python3 -m venv venv
    source venv/bin/activate
    mkdir -p package
    pip install -r requirements.txt --target ./package
    cd package
    zip -r ../function.zip .
    cd ..
    zip ./function.zip handler.py
    deactivate
    mv function.zip ../
    rm -rf venv package python 
)


