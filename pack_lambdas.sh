#!/bin/bash
set -e

lambda_functions=("producer_lambda")

for function in "${lambda_functions[@]}"; do
    echo "Building $function..."
    rm -rf $function.zip
    rm -rf $function/venv
    
    (
        cd $function || exit 1
        python3.12 -m venv venv
        source venv/bin/activate
        mkdir -p package
        pip install -r requirements.txt --target ./package
        cd package
        zip -r ../$function.zip .
        cd ..
        # zip ./$function.zip app.py dash_app.py __init__.py
        zip ./$function.zip handler.py
        mv ./$function.zip ../
    )

    
done



