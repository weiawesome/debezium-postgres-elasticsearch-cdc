FROM docker.io/confluentinc/cp-kafka-connect:7.7.7

USER root

RUN confluent-hub install --no-prompt \
      confluentinc/kafka-connect-elasticsearch:15.0.1 

RUN chown -R 1001:1001 /usr/share/confluent-hub-components

USER 1001