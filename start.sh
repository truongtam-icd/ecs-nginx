#!/bin/bash

export BASE_PATH=$(pwd)
export VPC_ID=$(awslocal ec2 describe-vpcs --query 'Vpcs[0].VpcId')
echo $VPC_ID
export SUBNET_ID=$(awslocal ec2 describe-subnets --query 'Subnets[?AvailabilityZone==`us-east-1a`].SubnetId' | sed -e "s/\[//g" | sed -e "s/\]//g")
echo $SUBNET_ID
export SECURITY_GROUPS=$(awslocal ec2 describe-security-groups --query 'SecurityGroups[0].GroupId')
echo $SECURITY_GROUPS

# if [[ -e ${BASE_PATH}/.env ]]; then
#   echo "Load file env"
#   export $(cat .env | xargs)
# else
#   echo "Load file example"
#   export $(cat env.example | xargs)
# fi

# Register a Linux Task Definition
awslocal ecs register-task-definition --cli-input-json file://./tasks/nginx.json
export DEFINITION=$(awslocal ecs list-task-definitions --query 'taskDefinitionArns[-1]' | sed -e "s/arn:aws:ecs:us-east-1:000000000000:task-definition\///g" | sed -e "s/\"//g")

export loadbalancerArn=$(awslocal elbv2 describe-load-balancers --query 'LoadBalancers[-1].LoadBalancerArn' | sed -e "s/\"//g")
export targetGroupArn=$(awslocal elbv2 describe-target-groups --query 'TargetGroups[-1].TargetGroupArn' | sed -e "s/\"//g")

# Create a Service
awslocal ecs create-service --cluster ecs-nginx-cluster --service-name \
   ecs-nginx-service --task-definition $DEFINITION --desired-count 1 \
  --load-balancers targetGroupArn=${targetGroupArn},loadBalancerName=ecs-load-balancer,containerName=ecs-nginx,containerPort=8080 \
  --enable-execute-command \
  --launch-type "FARGATE" \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUPS}]}"

# Check health
awslocal elbv2 describe-target-health --target-group-arn ${targetGroupArn}

# Get logs
export LOG_STREAM=$(awslocal logs describe-log-streams --log-group-name ecs-nginx-log --log-stream-name-prefix logs --query 'logStreams[-1].logStreamName' | sed -e "s/\"//g")
awslocal logs get-log-events --log-group-name ecs-nginx-log --log-stream-name ${LOG_STREAM} --limit 100

# Run run-task (test)
# export TASK=$(awslocal ecs list-tasks --cluster ecs-nginx-cluster --service ecs-nginx-service --query 'taskArns[0]' | sed -e "s/\"//g" | sed -e "s/\"//g")
# awslocal ecs describe-tasks --cluster ecs-nginx-cluster --tasks ${TASK}
# awslocal ecs run-task --cluster ecs-nginx-cluster --task-definition $DEFINITION --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUPS}]}"
