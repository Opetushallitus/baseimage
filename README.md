# baseimage

![Travis status](https://github.com/Opetushallitus/baseimage/actions/workflows/build.yml/badge.svg?branch=master)

Builder for various kinds of docker base images for Opetushallitus JVM-based services.

## Variants

Fourteen variants of baseimages are built by this builder. All images use [Amazon Corretto](https://aws.amazon.com/corretto/) with different tags as base image. These are selections which result in different images: 
- Image type: `fatjar` or `war` (i.e. tomcat)
    - if `war` then `tomcat7` or `tomcat8`
- JDK: `openjdk8`, `openjdk11` and `openjdk17`

Each variant is pushed in its own ECR repo:
- `baseimage-fatjar-openjdk8-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-fatjar-openjdk11-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-fatjar-openjdk17-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-war-openjdk8-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-war-tomcat8-openjdk8-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-war-openjdk11-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-war-tomcat8-openjdk11-corretto` (Amazon Linux 2 arm64/amd64)
- `baseimage-fatjar-openjdk8` (Alpine Linux amd64)
- `baseimage-fatjar-openjdk11` (Alpine Linux amd64)
- `baseimage-fatjar-openjdk17` (Alpine Linux amd64)
- `baseimage-war-openjdk8` (Alpine Linux amd64)
- `baseimage-war-tomcat8-openjdk8` (Alpine Linux amd64)
- `baseimage-war-openjdk11` (Alpine Linux amd64)
- `baseimage-war-tomcat8-openjdk11` (Alpine Linux amd64)

## Building on top of base images

To use a base image for your service, set the `BASE_IMAGE` variable in your `.travis.yml` when using utilities in 
https://github.com/Opetushallitus/ci-tools

You can either use the latest master build (recommended):

    export BASE_IMAGE="baseimage-fatjar-openjdk8:master"

or the latest build of a specific branch (my-branch):

    export BASE_IMAGE="baseimage-fatjar-openjdk8:my-branch"

or a specific build:

    export BASE_IMAGE="baseimage-fatjar-openjdk8:ga-39"

With this variable set, the `pull-image.sh` script in the `ci-tools` git repo pulls the correct image, and the 
`build-*.sh` script builds your image based on the base image.

## Contributing

Please use branches to avoid producing a broken image with the `master` tag. You can test your branch builds by pulling 
the specific version for a service.

You can test the build locally on your machine by running:

    docker build -t baseimage-fatjar-opendjk8:latest .
