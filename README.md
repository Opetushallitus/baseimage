# baseimage

![Travis status](https://api.travis-ci.org/Opetushallitus/baseimage.svg?branch=master)

Builder for various kinds of docker base images for Opetushallitus JVM-based services.

## Variants

Fourteen variants of baseimages are built by this builder. These are combinations of two ways of running the service: 
`fatjar` or `war` (i.e. tomcat), two OpenJDK vendors: `AdoptOpenJDK (deprecated)` and `Corretto (Amazon AWS provided)` and three JDK versions: `openjdk8`, `openjdk11` and `openjdk17`. The `war` variants have Tomcat 7 and Tomcat 8.5 options available. Non-Corretto variants should be removed when all the applications have moved to the new variants. 

Each variant is pushed in its own ECR repo, which are named:
- `baseimage-fatjar-openjdk8-corretto`
- `baseimage-fatjar-openjdk11-corretto`
- `baseimage-fatjar-openjdk17-corretto`
- `baseimage-war-openjdk8-corretto`
- `baseimage-war-tomcat8-openjdk8-corretto`
- `baseimage-war-openjdk11-corretto`
- `baseimage-war-tomcat8-openjdk11-corretto`
- `baseimage-fatjar-openjdk8` (deprecated)
- `baseimage-fatjar-openjdk11` (deprecated)
- `baseimage-fatjar-openjdk17` (deprecated)
- `baseimage-war-openjdk8` (deprecated)
- `baseimage-war-tomcat8-openjdk8` (deprecated)
- `baseimage-war-openjdk11` (deprecated)
- `baseimage-war-tomcat8-openjdk11` (deprecated)

## Building on top of base images

To use a base image for your service, set the `BASE_IMAGE` variable in your `.travis.yml` when using utilities in 
https://github.com/Opetushallitus/ci-tools

You can either use the latest master build (recommended):

    export BASE_IMAGE="baseimage-fatjar-openjdk8:master"

or the latest build of a specific branch:

    export BASE_IMAGE="baseimage-fatjar-openjdk8:my-branch"

or a specific build:

    export BASE_IMAGE="baseimage-fatjar-openjdk8:ci-35"

With this variable set, the `pull-image.sh` script in the `ci-tools` git repo pulls the correct image, and the 
`build-*.sh` script builds your image based on the base image.

## Contributing

Please use branches to avoid producing a broken image with the `master` tag. You can test your branch builds by pulling 
the specific version for a service.

You can test the build locally on your machine by running:

    docker build -t baseimage-fatjar-opendjk8:latest .
