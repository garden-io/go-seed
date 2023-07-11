# Go Seed
_If you love Garden, please ★ star this repository to show your support :green_heart:. Looking for support? Join our [Discord](https://go.garden.io/discord)._

<p align="center">
  <img src="https://github.com/garden-io/garden/assets/59834693/f62a04cb-44bc-4dd4-8426-398b6cd846fd" align="center">
</p>
<div align="center">
  <a href="https://docs.garden.io/basics/5-min-quickstart/?utm_source=github">Quickstart</a>
  <span>&nbsp;&nbsp;•&nbsp;&nbsp;</span>
  <a href="https://garden.io/?utm_source=github">Website</a>
  <span>&nbsp;&nbsp;•&nbsp;&nbsp;</span>
  <a href="https://docs.garden.io/?utm_source=github">Docs</a>
  <span>&nbsp;&nbsp;•&nbsp;&nbsp;</span>
  <a href="https://github.com/garden-io/garden/tree/0.13.0/examples">Examples</a>
  <span>&nbsp;&nbsp;•&nbsp;&nbsp;</span>
  <a href="https://garden.io/blog/?utm_source=github">Blog</a>
  <span>&nbsp;&nbsp;•&nbsp;&nbsp;</span>
  <a href="https://go.garden.io/discord">Discord</a>
</div>

This seed deploys a simple Go API using Helm and Garden to template our application and seamlessly deploy it to a local Kubernetes cluster ✅.

## TLDR

```bash
curl -sL https://get.garden.io/install.sh | bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath # Reload your terminal after this step.
pipx install cookiecutter
cookiecutter https://github.com/garden-io/go-seed.git # Answers the prompts to get your brand new repository
cd ${your-project-name}
garden deploy --sync
```

![Test video](https://ce-content.s3.fr-par.scw.cloud/garden-go-seed.gif)

## Structure of the template 🧪

Here's our file tree 🌲 which it's pretty simple as it only contains some Go code, a Helm chart and then Garden configuration.

```bash
├── Dockerfile
├── api.garden.yml
├── go.mod
├── go.sum
├── main.go
├── main_test.go
├── my-chart
│   ├── Chart.lock
│   ├── Chart.yaml
│   └── templates
│       └── app.yaml
└── project.garden.yml
```

## About the Go code ⌨️

This Go API example only uses `mux` to create our router and then basic packages like `fmt` and `net/http`.

We also included Unit Testing for the single endpoint this API `/` created.

[Reference file](./{{cookiecutter.app_name}}/main.go)

### Dockerizing our Go API 🐳

To use hot-reload in a compiled language, you'll need a library/package to re-compile the project when there is a code change.

We used [CompileDaemon](https://github.com/githubnemo/CompileDaemon), which watches our directory and invokes a `go build` if a file changes.

Using CompileDaemon or similar solutions in production might be unsafe as an attacker with write access can insert arbitrary code into your binary. ⚠️

You can fix this using multi-stage Dockerbuilds or different Dockerfiles for Dev & Prod or limit write access to your pod by enforcing `ReadOnly` file systems.

````Dockerfile
# Development Stage -> Garden uses this stage for the `local` environment.
FROM golang:1.20.0 AS development

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# We only need this dependency in development, as we use it to watch for changes
RUN go install -mod=mod github.com/githubnemo/CompileDaemon

# Copy the rest of the app
COPY . .

# Set the command to use CompileDaemon for hot-reloading
CMD CompileDaemon --build="go build main.go" --command=./main

# Builder stage, this will extract the dependencies and build the binary
FROM golang:1.20.0 AS builder

WORKDIR /app

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=bind,source=go.mod,target=go.mod \
    go mod download -x

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,target=. \
    CGO_ENABLED=0 go build -o /bin/main .

# Final production stage, using the smallest image possible (11.8MB in this case)
FROM alpine:3.14 as production

WORKDIR /app

# Creating a non-root user to run the application
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    go-runner
USER go-runner

# Copying the binary from the builder stage
COPY --from=builder /bin/main .

# Run it! 🚀
CMD ["/app/main"]

````

In the above Dockerfile, we can see best practices for Docker usage to obtain different images for Development and Production using the same .yaml file.

This allows us to use an 800MiB image in Dev, but only 11.8MB in Production.

## Helm Chart 📈

Our Helm Chart is straightforward as it only consists of a few files.

A chart definition `Chart.yaml` and a template file `app.yaml`.

[[Helmet](https://github.com/companyinfo/helm-charts/tree/main/charts/helmet) is a Helm library that helps us avoid repetitive work (DRY principle) by defining all the required resources for deploying to a Kubernetes cluster while offering extensive customization options, Helmet and Garden form a highly effective and efficient deployment solution.

Here's your `Chart.yaml` after you filled Cookiecutter's prompts ❤️.

````YAML
apiVersion: v2
name: my-chart
description: A Garden Helm Chart using Helmet library to deploy
type: application
version: "0.1.0"
maintainers:
  - name: {{ cookiecutter.full_name }} # This is how Cookiecutter templates vars by using Jinja2
    email: {{ cookiecutter.email }}

dependencies:
  - name: helmet
    version: 0.7.0
    repository: https://companyinfo.github.io/helm-charts
    import-values: # <== It is mandatory to import the Helmet default values.
      - defaults
````

Your file `templates/app.yaml` contains the necessary syntax to use Helmet as a Library.
````yaml
{{ include "helmet.app" . }}
````

### Garden Configuration Files 📂

A short tour of Garden project config and actions. ✅

Our `project.garden.yml` contains a global configuration that will help us to deploy this project with Garden.

````YAML
apiVersion: garden.io/v1
kind: Project
name: go-seed
defaultEnvironment: local
dotIgnoreFile: .gitignore

variables:
  # Replace underscores as Kubernetes namespaces do not allow them.
  user-namespace: go-seed-${kebabCase(local.username)} # make sure to explain all of this.
  registryHostname: docker.io # Replace with your own registry in case it's needed.
  registryNamespace: shankyweb # Replace this with your Dockerhub/Registry username.

environments:

  - name: local
    defaultNamespace: ${var.user-namespace}
    variables:
      base-hostname: local.demo.garden
      targetStage: development

  - name: production
    defaultNamespace: ${var.user-namespace}
    variables:
      base-hostname: {{cookiecutter.domain_name}}
      targetStage: production

providers:
  - name: local-kubernetes
    environments: [local]
    namespace: ${environment.namespace}
    defaultHostname: ${var.base-hostname}
    context: docker-desktop

  # Deploy to remote production environment using the same configuration as local.
  - name: kubernetes
    environments: [production]
    context: admin@main-ce
    setupIngressController: nginx
    buildMode: local-docker
    imagePullSecrets:
      - name: regcred
        namespace: default
    deploymentRegistry:
      hostname: ${variables.registryHostname}
      namespace: ${variables.registryNamespace}
    namespace: ${environment.namespace}
    defaultHostname: ${var.base-hostname}
````

As you might see above, we are adding a `local` environment to deploy our Go API into a local-kubernetes cluster using our context `docker-desktop`.

If you need more configuration for your microservice, the `variables` block is a great place to start, as you can customize env vars based on each environment.

Here we'll store our Garden Actions that will execute the stages of the SDLC (Build, Deploy, Test, Run).

````YAML
# Building our code with Garden
kind: Build
type: container
description: Build the Golang API
name: api-build
spec:
  targetStage: ${variables.targetStage} # This variable allows you to dynamically use the stage when a Multi-build docker is too complex.

---
````

Three dashes `---` in the file means that we are appending more YAML blocks as part of the same file. YAML identifies these as different files/blocks 🚧.

Let's review our `Deploy` action with type `helm` to deploy our service using our previously created Helm Chart.

````YAML
kind: Deploy
description: Helm deploy for the worker container
type: helm
name: api
dependencies: [build.api-build]
spec:
  # Sync configuration
  defaultTarget:
    kind: Deployment
    name: api
  sync:
    paths:
      - containerPath: /app
        sourcePath: .
        mode: one-way-replica
  # Configuring chart.
  chart:
    path: ./my-chart # Garden only support charts to be a sub-path, if you desire you can host this in Github and use repositoryUrl instead.
  values: # Override default values with Go container config, see all config available at https://github.com/companyinfo/helm-charts/tree/main
    image:
      registry: ${providers.kubernetes.config.deploymentRegistry.hostname}
      repository: ${providers.kubernetes.config.deploymentRegistry.namespace}/${actions.build.api-build.outputs.localImageName}
      tag: ${actions.build.api-build.version}
      pullPolicy: IfNotPresent
    ingress:
      enabled: true
      path: /
      hostname: api.${variables.base-hostname}
    ports:
      - name: http
        containerPort: 80
        protocol: TCP
    nameOverride: api
    fullnameOverride: api
---
````

In the following action, you can include your tests, such as unit tests, end-to-end (E2E) tests, or any other type of test you prefer to execute 🧪.

We provided a `Unit Test` to test functionality in this case.

````YAML
---
kind: Test
type: container
name: unit
description: Unit test for backend API
build: api-build
spec:
  args: ["go", "test"]
````
