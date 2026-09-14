# Docker

Runs Yamcs in a Docker container.

## Prerequisites

* make
* docker
* docker compose

## Commands

List the make targets:

    make

Clean, start Yamcs and check the database:

    make all

Start or stop the container:

    make yamcs-up
    make yamcs-down

Send the recorded frame and read the values back:

    make yamcs-check

Open a shell in the container:

    make yamcs-shell
