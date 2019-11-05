FROM avantaditya/todobackend-base:latest

MAINTAINER Aditya Avanth <avant.aditya@gmail.com>

#Install dev/build dependencies
RUN apt-get update &&\
    apt-get install -qy python-dev libmysqlclient-dev


#Activate virtualenv and install wheel support
RUN . /appenv/bin/activate &&\
    pip install wheel --upgrade

#PIP environment variables
ENV WHEELHOUSE=/wheelhouse PIP_WHEEL_DIR=/wheelhouse PIP_FIND_LINKS=/wheelhouse XDG_CACHE_HOME=/cache

#Build artifacts (wheels) are stord here
VOLUME /wheelhouse

#Build cache holding app source code and build dependencies
VOLUME /build

#test reports are stored here
VOLUME /reports

#Add entry point script
COPY scripts/test.sh /usr/local/bin/test.sh
RUN chmod +x /usr/local/bin/test.sh

#Add entrypoint script
ENTRYPOINT ["test.sh"]
CMD ["python", "manage.py", "test", "--noinput"]

COPY src /application
WORKDIR /application
