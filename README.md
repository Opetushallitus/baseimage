# baseimage-fatjar

A Docker base image for JVM-based services.

## Building on top of this base image

To use this base image for your service, set the `BASE_IMAGE` variable in your `.travis.yml`.

You can either use the latest master build (recommended):

    export BASE_IMAGE="baseimage-fatjar:latest-master"

or a specific version:

    export BASE_IMAGE="baseimage-fatjar:ci-9"

After you have set the variable, the `pull-image.sh` script pulls the correct image, and `build-*.sh` script will build your image based on the base image.

## Contributing

Please use branches to avoid producing a broken image with the `latest-master` tag. You can test your branch builds by pulling the specific version for a service.

You can test the build locally on your machine by running:

    docker build -t baseimage-fatjar:latest .
