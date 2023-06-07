#<a href="https://docs.localstack.cloud/getting-started/">Localstack for ecs-nginx</a>
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
  -e TEST_AWS_ACCOUNT_ID="000000000000" \
  -e DEFAULT_REGION="us-east-1" \
  -e LOCALSTACK_HOSTNAME="localhost" \
  -e HOSTNAME="localhost" \
  -e DEBUG=1 \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  -e HOST_TMP_FOLDER=/tmp/storage_localstack \
  -e DOCKER_SOCK=/var/run/docker.sock \
  -e DOCKER_CMD="sudo docker" \
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

###Localhost
```bash
http://ecs-nginx-local-load-balancer.elb.localhost.localstack.cloud:4566/
```

###Serverless
####Install
```bash
yarn install
```

####Build
```bash
yarn build
```

####Deploy
```bash
yarn deploy
```

#### ECR (Images node)
- Build
```bash
docker-compose -f docker-compose.nginx.yml up -d --build
```

- Run
```bash
# Start ECR
docker-compose -f docker-compose.nginx.yml start

# Stop ECR
docker-compose -f docker-compose.nginx.yml stop
```

- Other
```bash
# Login to ECR
docker exec -it <CONTAINER ID> sh

# Check ECR log
docker-compose -f docker-compose.nginx.yml logs -f --tail=50
```