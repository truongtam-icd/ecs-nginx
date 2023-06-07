#!/bin/bash

export BASE_PATH=$(pwd)
export VPC_ID=$(awslocal ec2 describe-vpcs --query 'Vpcs[0].VpcId' | sed -e "s/\"//g")
export SUBNET_ID=$(awslocal ec2 describe-subnets --query 'Subnets[?AvailabilityZone==`us-east-1a`].SubnetId' | sed -e "s/\[//g" | sed -e "s/\]//g" | sed -e "s/\
    //g" | tr '\r\n' ' ' | sed -e "s/ //g" | sed -e "s/\"//g")
export SECURITY_GROUPS=$(awslocal ec2 describe-security-groups --query 'SecurityGroups[0].GroupId' | sed -e "s/\"//g")

echo "VPC_ID=${VPC_ID}
SUBNET_ID=${SUBNET_ID}
SECURITY_GROUPS=${SECURITY_GROUPS}
" > .env

serverless deploy --stage local --region us-east-1 --aws-profile test --force

awslocal elbv2 describe-load-balancers
awslocal elbv2 describe-target-groups
export loadbalancerArn=$(awslocal elbv2 describe-load-balancers --query 'LoadBalancers[-1].LoadBalancerArn' | sed -e "s/\"//g")
export targetGroupArn=$(awslocal elbv2 describe-target-groups --query 'TargetGroups[-1].TargetGroupArn' | sed -e "s/\"//g")
awslocal elbv2 describe-listeners --load-balancer-arn ${loadbalancerArn}
awslocal elbv2 describe-target-health --target-group-arn ${targetGroupArn}