# Based on https://github.com/SemanticComputing/fuseki-docker/blob/master/Dockerfile
# Optimized to download JAR files from Apache repositories

FROM eclipse-temurin:21-jre-alpine AS base

# Allow version to be overridden during build
ARG JENA_VERSION=5.4.0
ENV JENA_VERSION=${JENA_VERSION}

# jq needed for tdb2.xloader, wget for downloading files
RUN apk add --update bash ca-certificates coreutils findutils jq pwgen ruby wget && rm -rf /var/cache/apk/*

# Config and data
ENV FUSEKI_BASE=/fuseki-base

# Fuseki installation
ENV FUSEKI_HOME=/jena-fuseki

ENV JENA_HOME=/jena
ENV JENA_BIN=$JENA_HOME/bin

WORKDIR /tmp
# Download, extract and install Fuseki
RUN echo "Downloading Apache Jena Fuseki ${JENA_VERSION}..." && \
    wget -O fuseki.tar.gz "https://dlcdn.apache.org/jena/binaries/apache-jena-fuseki-${JENA_VERSION}.tar.gz" && \
    echo "Extracting Fuseki..." && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz && \
    cd $FUSEKI_HOME && rm -rf fuseki.war && \
    echo "Fuseki installation completed"

# Download the GeoSPARQL extension JAR
RUN echo "Downloading GeoSPARQL extension ${JENA_VERSION}..." && \
    wget -O $FUSEKI_HOME/jena-fuseki-geosparql-${JENA_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/jena/jena-fuseki-geosparql/${JENA_VERSION}/jena-fuseki-geosparql-${JENA_VERSION}.jar" && \
    echo "GeoSPARQL extension downloaded"

# Download, extract and install Jena tools
RUN echo "Downloading Apache Jena ${JENA_VERSION}..." && \
    wget -O jena.tar.gz "https://dlcdn.apache.org/jena/binaries/apache-jena-${JENA_VERSION}.tar.gz" && \
    echo "Extracting Jena tools..." && \
    tar zxf jena.tar.gz && \
    mkdir -p $JENA_BIN && \
    mv apache-jena*/lib $JENA_HOME && \
    mv apache-jena*/bin/tdb1.xloader apache-jena*/bin/xload-* $JENA_BIN && \
    mv apache-jena*/bin/tdb2.xloader $JENA_BIN && \
    rm -rf apache-jena* && \
    rm jena.tar.gz && \
    echo "Jena tools installation completed"

# As "localhost" is often inaccessible within Docker container,
# we'll enable basic-auth with a random admin password
# (which we'll generate on start-up)
COPY config/shiro.ini /jena-fuseki/shiro.ini
COPY config/docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

# SeCo extensions (commented out - file not found in current setup)
# If you need this extension, place the JAR file in a bin/ directory and uncomment the line below
# COPY bin/silk-arq-1.0.0-SNAPSHOT-with-dependencies.jar /javalibs/
RUN mkdir -p /javalibs

# Fuseki config
ENV ASSEMBLER=$FUSEKI_BASE/configuration/assembler.ttl
COPY config/assembler.ttl $ASSEMBLER
ENV CONFIG=$FUSEKI_BASE/config.ttl
COPY config/fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE

# Tools for loading data
ENV JAVA_CMD='java -cp "$FUSEKI_HOME/fuseki-server.jar:/javalibs/*"'
ENV TDBLOADER='$JAVA_CMD tdb.tdbloader --desc=$ASSEMBLER'
ENV TDB1XLOADER='$JENA_BIN/tdb1.xloader --loc=$FUSEKI_BASE/databases/tdb'
ENV TDB2TDBLOADER='$JAVA_CMD tdb2.tdbloader --desc=$ASSEMBLER'
ENV TDB2XLOADER='$JENA_BIN/tdb2.xloader --loc=$FUSEKI_BASE/databases/tdb'
ENV TEXTINDEXER='$JAVA_CMD jena.textindexer --desc=$ASSEMBLER'
ENV TDBSTATS='$JAVA_CMD tdb.tdbstats --desc=$ASSEMBLER'
ENV TDB2TDBSTATS='$JAVA_CMD tdb2.tdbstats --desc=$ASSEMBLER'

WORKDIR /jena-fuseki
EXPOSE 3030
USER 9008

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]