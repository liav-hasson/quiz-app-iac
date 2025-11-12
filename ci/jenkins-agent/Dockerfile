FROM jenkins/inbound-agent:latest

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip \
    ansible \
    curl unzip gnupg \
    shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
ENV TERRAFORM_VERSION=1.9.5
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    -o terraform.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform.zip

USER jenkins
WORKDIR /home/jenkins
