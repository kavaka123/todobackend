#!/bin/bash

. /appenv/bin/activate

# Download dependencies to build cache
pip download -d /build -r requirements_test.txt --no-input

#Install application test requirements
pip install --no-index -f /build -r requirements_test.txt

#Run test arguments
exec $@