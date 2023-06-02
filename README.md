#<a href="https://docs.localstack.cloud/getting-started/">Localstack for human-resource</a>
##<a href="https://github.com/localstack/awscli-local">Install awslocal cli</a>
####Require
Python3: >=3.10.x<br>
pip3: >=22.3.x
```bash
pip install awscli-local
```

##<a href="https://docs.localstack.cloud/getting-started/installation/#docker">Start localstack-pro by docker</a>
```bash
docker run -d \
  --name localstack_main \
  --rm -it \
  -p 4566:4566 \
  -p 4510-4559:4510-4559 \
  -p 8080-8081:8080-8081 \
  -e TEST_AWS_ACCOUNT_ID="000000000000" \
  -e DEFAULT_REGION="us-east-1" \
  -e LOCALSTACK_HOSTNAME="localhost" \
  -e DEBUG=1 \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  -e HOST_TMP_FOLDER=/tmp/storage_localstack \
  -v "/tmp/localstack:/tmp/localstack" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -e LOCALSTACK_API_KEY={LOCALSTACK_API_KEY} \
  localstack/localstack-pro
```

###Run by shell script ECS
Install
```bash
./setup.sh
```

Start
```bash
./start.sh
```

###Step by step install ECS
####1. Create S3 + Log Group
```bash
awslocal s3api create-bucket --bucket human-resource
awslocal s3api list-buckets
awslocal logs create-log-group --log-group-name human-resource-log
awslocal logs create-log-stream --log-group-name human-resource-log --log-stream-name logs
```

####2. Get VPC + Subnet + Security Groups
```bash
awslocal ec2 describe-vpcs
  example: vpc-f478c2ec
awslocal ec2 describe-subnets
  example:
    Zone: us-east-1a
    ID: subnet-779c549c
awslocal ec2 describe-security-groups
  example: sg-03687374fd3cc2fd6
```

####3. Create IamManagedPolicies
```bash
awslocal iam list-policies --query 'Policies[?PolicyName==`PowerUserAccess`].{ARN:Arn}'
awslocal iam create-user --user-name HRUser --region us-east-1
export POLICYARN=arn:aws:iam::aws:policy/PowerUserAccess
awslocal iam attach-user-policy --user-name HRUser --policy-arn $POLICYARN
awslocal iam list-attached-user-policies --user-name HRUser
```

####4. Create ECR
```bash
awslocal ecr create-repository --repository-name human-resource
awslocal ecr get-login-password --region us-east-1 | docker login --username HRUser --password-stdin localhost:4510
cd ~/project/human-resource && docker build -f ./docker/Node.Dockerfile -t localhost:4510/human-resource .
cd ~/project/human-resource && docker push localhost:4510/human-resource
awslocal ecr list-images --repository-name human-resource

```


####5. Create a Cluster
```bash
awslocal ecs create-cluster --cluster-name human-resource-cluster
awslocal ecs list-clusters
```

####6. Register a Linux Task Definition
```bash
cd ~/project/human-resource/localstack && awslocal ecs register-task-definition --cli-input-json file://./tasks/version.json
awslocal ecs list-task-definitions
```

####7. Create a Service
```bash
awslocal ecs create-service --cluster human-resource-cluster --service-name human-resource-service --enable-execute-command --task-definition human-resource:1 --desired-count 1 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUPS}]}"
awslocal ecs list-services --cluster human-resource-cluster
awslocal ecs describe-services --cluster human-resource-cluster --services human-resource-service
```

####8. Test
```bash
export TASK=$(awslocal ecs list-tasks --cluster human-resource-cluster --service human-resource-service --query 'taskArns[0]'| sed -e "s/\"//g" | sed -e "s/\"//g")
awslocal ecs describe-tasks --cluster human-resource-cluster --tasks ${TASK}
awslocal ecs run-task --cluster human-resource-cluster --task-definition human-resource:1 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SECURITY_GROUPS}]}"
```

####9. Clean Up
```bash
awslocal ecs delete-service --cluster human-resource-cluster --service human-resource-service --force
awslocal ecs delete-cluster --cluster human-resource-cluster
```
