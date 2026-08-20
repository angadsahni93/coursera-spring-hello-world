Just a sample hello world application using Java/Spring Boot

## CI/CD schematic:

```text
CI: code -> tests/build -> Docker image -> push to Elastic Container Registry (ECR; on AWS)
CD: registry image -> pull to server (EC2 - manual docker pull set up; ECS - container orchestration service) -> create/update running container
```


## EC2 Setup Commands in Your Machine's Terminal

EC2 is the AWS virtual server used to pull Docker images and run containers for deployment.

> Purpose of `script.sh` on EC2:

```text
script.sh is used to set up the EC2 server environment, for example installing Docker, Docker Compose, and AWS/ECR helper tools so the server can pull and run Docker images from ECR.
```

> Purpose of `Spring-boot-keys.pem`:

```text
Spring-boot-keys.pem is the private SSH key that proves you are allowed to connect to the EC2 instance. It is used by scp to copy files to EC2 and by ssh to log into EC2.
```

To create the `SSH_PRIVATE_KEY_EC2` GitHub Secret, copy the full contents of the `.pem` file:

```bash
cat Spring-boot-keys.pem
```

Save the copied value in GitHub under `Settings -> Secrets and variables -> Actions -> New repository secret` with the name `SSH_PRIVATE_KEY_EC2`. Do not commit the `.pem` file to GitHub.

1. Secure the private key file on your Mac so only your Mac user can read it. SSH requires this before it will use the key.

```bash
chmod 400 Spring-boot-keys.pem
```

2. Copy `script.sh` from your Mac to the EC2 server's home folder.

```bash
scp -i Spring-boot-keys.pem script.sh ubuntu@51.20.182.222:~/
```

3. Log into the EC2 server so you can run commands on it.

```bash
ssh -i Spring-boot-keys.pem ubuntu@51.20.182.222
```

4. Give permission to run `script.sh` as a program on the EC2 server.

```bash
chmod +x script.sh
```

5. Run the setup script on the EC2 server.

```bash
./script.sh
```

6. Pull the Redis image from Docker Hub to confirm Docker can download images on the EC2 server.

```bash
docker pull redis
```

## EC2 Deployment Compose File

After setting up the `deploy` job in `pipeline.yml`, create or edit `docker-compose.yml` on the EC2 server:

```bash
nano docker-compose.yml
```

This file is needed on EC2 because the deploy job runs Docker Compose commands on the EC2 server:

```yaml
script:
  - docker compose pull
  - docker compose up -d --force-recreate
```

The EC2 `docker-compose.yml` tells Docker which image to pull from ECR, which container to run, and which ports to expose.

Example EC2 `docker-compose.yml`:

```yaml
version: "3.8"

services:
  app:
    image: 898732116894.dkr.ecr.eu-north-1.amazonaws.com/coursera/spring-boot-docker:latest
    ports:
      - "8080:80"
```

The port mapping is correct:

```text
EC2 port 8080 -> container port 80
```

So the app should be reached through EC2 on port `8080`, while the Spring Boot container still listens internally on port `80`.


## GitHub Actions Pipeline Flow (.github/workflows/pipeline.yml)

```text
[1] name: CI/CD Pipeline

    Gives the GitHub Actions workflow a readable name in the Actions tab.
    Flows to the trigger rules below.

        |
        v

[2] on:
      push:
        branches:
        - main
      workflow_dispatch:

    Runs the pipeline when code is pushed to the main branch.
    Also allows the workflow to be started manually from GitHub.
    Flows to the jobs that GitHub should run.

        |
        v

[3] jobs:
      build:
        runs-on: ubuntu-latest

    Creates a build job on a temporary GitHub-hosted Ubuntu runner.
    This runner is where the Docker image is built and pushed.
    Flows to the ordered steps inside the job.

        |
        v

[4] - name: Checkout code
      uses: actions/checkout@v3

    Downloads this repository's code onto the GitHub runner.
    Without this, the runner would not have the Dockerfile or app source.
    Flows to AWS authentication.

        |
        v

[5] - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}

    Authenticates the GitHub runner with AWS using GitHub Secrets.
    This allows later steps to access AWS services such as ECR.
    Flows to logging in to Amazon ECR.

        |
        v

[6] - name: Login to Amazon ECR
      uses: aws-actions/amazon-ecr-login@v2

    Logs Docker in to Amazon Elastic Container Registry.
    This allows Docker to push images to the private ECR repository.
    Flows to building the Docker image.

        |
        v

[7] - name: Build Docker image
      run:
        docker build -t ${{ secrets.ECR_REPO }}:latest .

    Builds a Docker image from the Dockerfile in this repository.
    Tags the image with the ECR repository path and the latest tag.
    Flows to pushing the image to ECR.

        |
        v

[8] - name: Push Docker image to Amazon ECR
      run:
        docker push ${{ secrets.ECR_REPO }}:latest

    Pushes the built Docker image from the GitHub runner to Amazon ECR.
    ECR then stores the image so AWS services such as EC2 or ECS can pull it.
```
