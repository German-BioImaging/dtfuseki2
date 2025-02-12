#   Licensed to the Apache Software Foundation (ASF) under one or more
#   contributor license agreements.  See the NOTICE file distributed with
#   this work for additional information regarding copyright ownership.
#   The ASF licenses this file to You under the Apache License, Version 2.0
#   (the "License"); you may not use this file except in compliance with
#   the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

FROM openjdk:19-slim AS base

LABEL maintainer="jouni.tuominen@aalto.fi"

RUN apt-get update \
 && apt-get install -qq pwgen ruby wget

# Update below according to htps://jena.apache.org/download/
ENV FUSEKI_SHA512 1d60d596a4aa6f3c786e0da86190e406152ed2f5e0698960c6065a0b85bef5bde9844771ddb7cb22aefd95e38c1510ae4ac4d089a484211edc167080ec3af452
ENV FUSEKI_VERSION 4.5.0
ENV JENA_SHA512 84e23ca41e8e38b286abf769d3ccdfe069f6157d58e0bb24e78d98ed5f8d598e06ededc16dd5bde0a494d5ee7c49ab9c4f5335cf63727a302e6b8b929d47457f
ENV JENA_VERSION 4.5.0

ENV MIRROR https://dlcdn.apache.org
ENV ARCHIVE http://archive.apache.org/dist

# Config and data
ENV FUSEKI_BASE /fuseki-base

# Fuseki installation
ENV FUSEKI_HOME /jena-fuseki

ENV JENA_HOME /jena
ENV JENA_BIN $JENA_HOME/bin

WORKDIR /tmp
# sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512
# Download/check/unpack/move Fuseki in one go (to reduce image size)
RUN wget -O fuseki.tar.gz $MIRROR/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz || \
    wget -O fuseki.tar.gz $ARCHIVE/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz && \
    sha512sum -c fuseki.tar.gz.sha512 && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz* && \
    cd $FUSEKI_HOME && rm -rf fuseki.war

# Get tdbloader2 from Jena
# sha512 checksum
RUN echo "$JENA_SHA512  jena.tar.gz" > jena.tar.gz.sha512
# Download/check/unpack/move Jena in one go (to reduce image size)
RUN wget -O jena.tar.gz $MIRROR/jena/binaries/apache-jena-$JENA_VERSION.tar.gz || \
    wget -O jena.tar.gz $ARCHIVE/jena/binaries/apache-jena-$JENA_VERSION.tar.gz && \
    sha512sum -c jena.tar.gz.sha512 && \
    tar zxf jena.tar.gz && \
	mkdir -p $JENA_BIN && \
	mv apache-jena*/lib $JENA_HOME && \
	mv apache-jena*/bin/tdbloader2* $JENA_BIN && \
    rm -rf apache-jena* && \
    rm jena.tar.gz*

# As "localhost" is often inaccessible within Docker container,
# we'll enable basic-auth with a random admin password
# (which we'll generate on start-up)
COPY shiro.ini /jena-fuseki/shiro.ini
COPY docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

# SeCo extensions
COPY silk-arq-1.0.0-SNAPSHOT-with-dependencies.jar /javalibs/

# Fuseki config
ENV ASSEMBLER $FUSEKI_BASE/configuration/assembler.ttl
COPY assembler.ttl $ASSEMBLER
ENV CONFIG $FUSEKI_BASE/config.ttl
COPY fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE

# Tools for loading data
ENV JAVA_CMD java -cp "$FUSEKI_HOME/fuseki-server.jar:/javalibs/*"
ENV TDBLOADER $JAVA_CMD tdb.tdbloader --desc=$ASSEMBLER
ENV TDBLOADER2 $JENA_BIN/tdbloader2 --loc=$FUSEKI_BASE/databases/tdb
ENV TDB2TDBLOADER $JAVA_CMD tdb2.tdbloader --desc=$ASSEMBLER
ENV TEXTINDEXER $JAVA_CMD jena.textindexer --desc=$ASSEMBLER
ENV TDBSTATS $JAVA_CMD tdb.tdbstats --desc=$ASSEMBLER
ENV TDB2TDBSTATS $JAVA_CMD tdb2.tdbstats --desc=$ASSEMBLER

WORKDIR /jena-fuseki
EXPOSE 3030
USER 9008

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.cmd.FusekiCmd"]
