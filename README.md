### Updated README for Alpine-based Concourse Docker-in-Docker

# Concourse Docker-in-Docker

Docker in Docker Alpine container for Concourse CI. Optimized for use with [Concourse CI](http://concourse.ci/). 
Images are published under `ghcr.io/dalglish14/concourse-dind` which includes Docker and Docker Compose.

## Features

- Automatically starts Docker.
- Uses **errexit**, **pipefail**, and **nounset**.
- Configures timeout (`DOCKERD_TIMEOUT`) on `dockerd` start to account for misconfiguration (docker log will be output).
- Accepts arbitrary `dockerd` arguments via optional `DOCKER_OPTS` environment variable.
- Passes through `--garden-mtu` from the parent Gardian container if `--mtu` is not specified in `DOCKER_OPTS`.
- Sets `--data-root /scratch/docker` to bypass the graph filesystem if `--data-root` is not specified in `DOCKER_OPTS`.

## Example
Here is an example of a Concourse [job](http://concourse.ci/concepts.html) to run several containers in a task, and then run the integration test suite.

```yaml
jobs:
- name: integration
  plan:
  - get: code
    params:
      depth: 1
    passed:
    - unit-tests
    trigger: true
  - task: integration-tests
    privileged: true
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: ghcr.io/dalglish14/concourse-dind
      inputs:
      - name: code
      run:
        args:
        - bash
        - -ceux
        - |
          docker-compose -f code/example/integration.yml run tests
          docker-compose -f code/example/integration.yml down
          docker volume rm $(docker volume ls -q)
```
