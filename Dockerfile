FROM mongo

RUN apt-get update && apt-get -y install awscli

ADD run.sh /run.sh
CMD /run.sh
