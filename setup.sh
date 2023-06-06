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

# Create S3 + Log Group
awslocal s3api create-bucket --bucket ecs-nginx
awslocal logs create-log-group --log-group-name ecs-nginx-log
awslocal logs create-log-stream --log-group-name ecs-nginx-log --log-stream-name logs
awslocal s3api list-buckets

# Create IamManagedPolicies user is User
awslocal iam create-user --user-name User --region us-east-1
awslocal iam attach-user-policy --user-name User --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"
awslocal iam list-attached-user-policies --user-name User

# Create load balancer & target group
awslocal elbv2 create-load-balancer --name ecs-load-balancer \
  --subnets $( echo $SUBNET_ID | sed -e "s/\n//g" | sed -e "s/\"//g")
awslocal elbv2 create-target-group --name ecs-targets-group \
  --protocol HTTP --target-type ip  --port 8080 \
  --vpc-id ${VPC_ID}
export loadbalancerArn=$(awslocal elbv2 describe-load-balancers --query 'LoadBalancers[-1].LoadBalancerArn' | sed -e "s/\"//g")
export targetGroupArn=$(awslocal elbv2 describe-target-groups --query 'TargetGroups[-1].TargetGroupArn' | sed -e "s/\"//g")

# Create ECR
awslocal ecr create-repository --repository-name ecs-nginx
awslocal ecr get-login-password --region us-east-1 | docker login --username User --password-stdin localhost:4510
docker build -f ./docker/Dockerfile -t localhost:4510/ecs-nginx .
docker push localhost:4510/ecs-nginx
awslocal ecr list-images --repository-name ecs-nginx

# Create a Cluster
awslocal ecs create-cluster --cluster-name ecs-nginx-cluster
awslocal ecs list-clusters

# Register a Linux Task Definition
awslocal ecs register-task-definition --cli-input-json file://./tasks/nginx.json
awslocal ecs list-task-definitions --query 'taskDefinitionArns[-1]'

export targetGroupArn=$(awslocal elbv2 describe-target-groups --query 'TargetGroups[-1].TargetGroupArn' | sed -e "s/\"//g")

# Create a Service
awslocal ecs create-service --cluster ecs-nginx-cluster --service-name \
  ecs-nginx-service --task-definition ecs-nginx:1 --desired-count 1 \
  --load-balancers targetGroupArn=${targetGroupArn},loadBalancerName=ecs-load-balancer,containerName=ecs-nginx,containerPort=8080 \
  --enable-execute-command \
  --launch-type "FARGATE" \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUPS}]}"

# Get ID target
awslocal elbv2 describe-target-health --target-group-arn ${targetGroupArn}
export Id_Target=$(awslocal elbv2 describe-target-health --target-group-arn ${targetGroupArn} --query 'TargetHealthDescriptions[-1].Target.Id' | sed -e "s/\"//g")

# Add listener load balancer
awslocal elbv2 register-targets --targets Id=${Id_Target},Port=8080,AvailabilityZone=all \
  --target-group-arn $targetGroupArn
awslocal elbv2 create-listener \
  --default-actions '{"Type":"forward","TargetGroupArn":"'${targetGroupArn}'","ForwardConfig":{"TargetGroups":[{"TargetGroupArn":"'${targetGroupArn}'","Weight":11}]}}' \
  --load-balancer-arn ${loadbalancerArn}
export listenerArn=$(awslocal elbv2 describe-listeners --load-balancer-arn ${loadbalancerArn} --query 'Listeners[-1].ListenerArn' | sed -e "s/\"//g")
awslocal elbv2 create-rule \
  --conditions Field=path-pattern,Values=/ \
  --priority 1 \
  --actions '{"Type":"forward","TargetGroupArn":"'${targetGroupArn}'","ForwardConfig":{"TargetGroups":[{"TargetGroupArn":"'${targetGroupArn}'","Weight":11}]}}' \
  --listener-arn ${listenerArn}

# Check health
awslocal elbv2 describe-target-health --target-group-arn ${targetGroupArn}

# Get logs
export LOG_STREAM=$(awslocal logs describe-log-streams --log-group-name ecs-nginx-log --log-stream-name-prefix logs --query 'logStreams[-1].logStreamName' | sed -e "s/\"//g")
awslocal logs get-log-events --log-group-name ecs-nginx-log --log-stream-name ${LOG_STREAM} --limit 100
