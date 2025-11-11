# Based on https://github.com/SemanticComputing/fuseki-docker/blob/master/Dockerfile

FROM eclipse-temurin:21-jre-alpine AS base

# Allow versions to be overridden during build
ARG JENA_VERSION=5.6.0
ENV JENA_VERSION=${JENA_VERSION}

ARG SIS_VERSION=1.4
ENV SIS_VERSION=${SIS_VERSION}

ARG DERBY_VERSION=10.15.2.0
ENV DERBY_VERSION=${DERBY_VERSION}

# Install Maven and required tools
# jq needed for tdb2.xloader, unzip for SIS datasets
RUN apk add --no-cache --update bash ca-certificates coreutils findutils jq pwgen ruby unzip maven && rm -rf /var/cache/apk/*

# Config and data
ENV FUSEKI_BASE=/fuseki-base

# Fuseki installation
ENV FUSEKI_HOME=/jena-fuseki

ENV JENA_HOME=/jena
ENV JENA_BIN=$JENA_HOME/bin

WORKDIR /tmp

# Download and install Apache SIS binary distribution
ENV SIS_HOME=/apache-sis
ENV SIS_DATA=$FUSEKI_BASE/sis_data
RUN mkdir -p $SIS_DATA && mkdir -p $SIS_HOME && mkdir -p $SIS_HOME/log

ENV PATH=$PATH:$SIS_HOME/bin

# Use Maven to download all dependencies as JARs
COPY pom.xml /tmp/pom.xml
# Override default versions in the POM with build-time args
RUN sed -i \
    -e "s|<sis.version>.*</sis.version>|<sis.version>${SIS_VERSION}</sis.version>|g" \
    /tmp/pom.xml
RUN mkdir -p /javalibs && \
    mvn dependency:copy-dependencies -DoutputDirectory=/javalibs -f /tmp/pom.xml && \
    echo "All dependencies downloaded to /javalibs"

COPY config/shiro.ini /jena-fuseki/shiro.ini
COPY config/docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

# Fuseki config
ENV ASSEMBLER=$FUSEKI_BASE/configuration/assembler.ttl
COPY config/assembler.ttl $ASSEMBLER
ENV CONFIG=$FUSEKI_BASE/config.ttl
COPY config/fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE \
    && chgrp -R 0 $SIS_HOME \
    && chmod -R g+rX $SIS_HOME \
    && chmod -R g+rwX $SIS_HOME/log \
    && mkdir -p $FUSEKI_BASE/derby-logs \
    && chgrp -R 0 $FUSEKI_BASE/derby-logs \
    && chmod -R g+rwX $FUSEKI_BASE/derby-logs

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

# Healthcheck: check if Fuseki is responding on port 3030
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget --spider --no-verbose http://localhost:3030/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]
#CMD ["java", "-cp", "*:/javalibs/*", "-Dlog4j.configurationFile=/fuseki-base/log4j2.properties", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]
#CMD ["java", "-cp", "*:/javalibs/*", "-Dlog4j.configurationFile=/fuseki-base/log4j2.properties", "-DSIS_DATA=/fuseki-base/SIS_DATA", "-Dorg.apache.sis.referencing.factory.sql.EPSG.embedded=true", "-Dderby.stream.error.file=/fuseki-base/derby-logs/derby.log", "-Dderby.system.home=/fuseki-base/derby-logs", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]
#CMD ["java", "-cp", "*:/javalibs/*", "-Dlog4j.configurationFile=/fuseki-base/log4j2.properties", "-Dderby.stream.error.file=/fuseki-base/derby-logs/derby.log", "-DSIS_DATA=/fuseki-base/sis_data", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]
