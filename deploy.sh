#!/bin/bash

DATADOG_DD_SITE="${DATADOG_DD_SITE:=us5.datadoghq.com}"
DATADOG_SECRET_NAME="${DATADOG_SECRET_NAME:=datadog_id}"

aws cloudformation deploy --template-file image-repo.yaml --stack-name metrics-demo-repos --tags Demo=MetricDemo
ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')
REGION=$(aws configure get region)
IMAGE_REPO=$(aws cloudformation describe-stacks --stack-name metrics-demo-repos)
SERVICE_REPO_URI=$(echo $IMAGE_REPO | jq -r '.Stacks[] | select(.StackName == "metrics-demo-repos") | .Outputs[] | select(.OutputKey == "WeatherServiceImageRepoUri") | .OutputValue')
SERVICE_REPO_ARN=$(echo $IMAGE_REPO | jq -r '.Stacks[] | select(.StackName == "metrics-demo-repos") | .Outputs[] | select(.OutputKey == "WeatherServiceImageRepoArn") | .OutputValue')
CLIENT_REPO_URI=$(echo $IMAGE_REPO | jq -r '.Stacks[] | select(.StackName == "metrics-demo-repos") | .Outputs[] | select(.OutputKey == "WeatherClientImageRepoUri") | .OutputValue')
CLIENT_REPO_ARN=$(echo $IMAGE_REPO | jq -r '.Stacks[] | select(.StackName == "metrics-demo-repos") | .Outputs[] | select(.OutputKey == "WeatherClientImageRepoArn") | .OutputValue')

aws ecr get-login-password | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

docker build -t metrics-weather-service:latest WeatherForecastService
docker tag metrics-weather-service:latest "${SERVICE_REPO_URI}:latest"
docker push "${SERVICE_REPO_URI}:latest"
SERVICE_IMAGE_URI_WITH_TAG=$(docker inspect metrics-weather-service:latest |  jq -r '.[0].RepoDigests[0]')

docker build -t metrics-weather-client:latest SimulatedClients
docker tag metrics-weather-client:latest "${CLIENT_REPO_URI}:latest"
docker push "${CLIENT_REPO_URI}:latest"
CLIENT_IMAGE_URI_WITH_TAG=$(docker inspect metrics-weather-client:latest | jq -r '.[0].RepoDigests[0]')

DATADOG_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id $DATADOG_SECRET_NAME | jq -r '.ARN')

aws cloudformation deploy \
    --template-file cfn.yaml \
    --stack-name metrics-demo \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        DatadogSecretArn="${DATADOG_SECRET_ARN}" \
        WeatherServiceImageRepoArn="${SERVICE_REPO_ARN}" \
        WeatherServiceUriWithTag="${SERVICE_IMAGE_URI_WITH_TAG}" \
        SimulatedClientUriWithTag="${CLIENT_IMAGE_URI_WITH_TAG}" \
        DatadogDdSiteVariable="${DATADOG_DD_SITE}" \
    --tags \
        Demo=MetricDemo

aws cloudformation wait stack-create-complete --stack-name metrics-demo

LB_HOSTNAME=$(aws cloudformation describe-stacks --stack-name metrics-demo | jq -r '.Stacks[] | select(.StackName == "metrics-demo") | .Outputs[] | select(.OutputKey == "LoadBalancerHostname") | .OutputValue')

echo "Load balancer URL is http://${LB_HOSTNAME}"
echo "Visit Swagger UI at http://${LB_HOSTNAME}/Swagger/"