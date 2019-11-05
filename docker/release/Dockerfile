FROM avantaditya/todobackend-base
MAINTAINER Aditya Avanth <avant.aditya@gmail.com>

#Copy build artifacts to container
COPY target /wheelhouse

#Activate virtual env and install build artifacts
RUN . /appenv/bin/activate &&\
    pip install --no-index -f /wheelhouse todobackend &&\
    rm -rf /wheelhouse

