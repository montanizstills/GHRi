FROM ubuntu:latest as build
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /actions-runner

RUN apt-get update
RUN apt-get install -y --fix-missing -qq curl software-properties-common apt-utils
RUN add-apt-repository universe
RUN curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN apt-get update && apt-get upgrade
RUN ACCEPT_EULA=Y apt-get install --fix-missing -y -qq systemctl libicu-dev unixodbc-dev msodbcsql17 sudo
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Download self-hosted runner files.
RUN curl -O -L https://github.com/actions/runner/releases/download/v2.303.0/actions-runner-linux-x64-2.303.0.tar.gz && \
    tar xzf ./actions-runner-linux-x64-2.303.0.tar.gz && \
    rm actions-runner-linux-x64-2.303.0.tar.gz

# Edit configure and run script to stop `exit 1` if sudo user.
RUN sed -i '/echo "Must not run with sudo"/{n;s/^/# /;}' config.sh
# && sed -i '/echo "Must not run interactively with sudo"/{n;s/^/# /;}' run.sh

#
# Option 1
# This method makes the token ephemeral and obfuscated in `docker history` Must have secrets.txt file.
# DOCKER_BUILDKIT=1 docker build --secret=id=<id>,src=<path/to/file.txt> - t <img_tag> -f <dockerfile> .
#RUN --mount=type=secret,id=action_runner_token \
#    echo "$(cat /run/secrets/action_runner_token)" | ./config.sh --url https://github.com/vertexinc/vc-dr-test --token -n
#
# Option 2
# This method relies on the deployment tool. Must have `ARG ACTION_RUNNER_TOKEN` in dockerfile.
# docker build --build-arg ACTION_RUNNER_TOKEN=**** -t <img_tag> -f <dockerfile> .
#RUN ./config.sh --url https://github.com/vertexinc/vc-dr-test --token $ACTION_RUNNER_TOKEN
#
# Option 3
# This method shows the token as plain text (not recommended). Must replace <token> with a shortlived token from (https://github.com/vertexinc/vc-dr-test/settings/actions/runners/new).
# docker build --squash -t <image_name> -f <dockerfile> .
RUN ./config.sh --url https://github.com/vertexinc/vc-dr-test \
    --token <token> --name 'vcd-runner' --work 'iterations' --replace

# Configure the runner.
RUN ./config.sh --url https://github.com/vertexinc/vc-dr-test \
    --token <token> --name 'vcd-runner' --work 'iterations' --replace

# Confiugure image as a service
RUN ./svc.sh install

# Finally we can push the final image to the repository. This image will run our pre-configured runner from the base image.
# Use  `docker build --squash -t <image_name> -f <dockerfile> .` to squash base_layer(s) and obfuscate sensitive data.
FROM build
COPY --from=build /actions-runner .
# CMD ["systemctl","start","actions.runner.vertexinc-vc-dr-test.vcd-runner.service"]
ENTRYPOINT ["/bin/bash"]