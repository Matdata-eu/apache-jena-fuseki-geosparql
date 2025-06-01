# Based on https://github.com/SemanticComputing/fuseki-docker/blob/master/Dockerfile
# Optimized to download JAR files from Apache repositories

FROM eclipse-temurin:21-jre-alpine AS base

# Allow versions to be overridden during build
ARG JENA_VERSION=5.4.0
ENV JENA_VERSION=${JENA_VERSION}

ARG SIS_VERSION=1.4
ENV SIS_VERSION=${SIS_VERSION}

ARG DERBY_VERSION=10.15.2.0
ENV DERBY_VERSION=${DERBY_VERSION}

# jq needed for tdb2.xloader, wget for downloading files, unzip for SIS datasets
RUN apk add --update bash ca-certificates coreutils findutils jq pwgen ruby wget unzip && rm -rf /var/cache/apk/*

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

# Download and install Apache SIS binary distribution
ENV SIS_HOME=/apache-sis
ENV SIS_DATA=$FUSEKI_BASE/sis_data
RUN echo "Downloading Apache SIS binary distribution ${SIS_VERSION}..." && \
    wget -O /tmp/apache-sis-${SIS_VERSION}-bin.zip \
    "https://dlcdn.apache.org/sis/${SIS_VERSION}/apache-sis-${SIS_VERSION}-bin.zip" && \
    echo "Extracting Apache SIS..." && \
    cd /tmp && \
    unzip -q apache-sis-${SIS_VERSION}-bin.zip && \
    mv apache-sis-${SIS_VERSION} $SIS_HOME && \
    rm apache-sis-${SIS_VERSION}-bin.zip && \
    mkdir -p $SIS_DATA && \
    echo "Apache SIS binary distribution installed"

# Create javalibs directory and download SIS embedded data dependency for metre-based distance calculations
RUN mkdir -p /javalibs && \
    echo "Downloading SIS embedded data dependency ${SIS_VERSION}..." && \
    wget -O /javalibs/sis-embedded-data-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/non-free/sis-embedded-data/${SIS_VERSION}/sis-embedded-data-${SIS_VERSION}.jar" && \    
    echo "Downloading additional SIS dependencies for coordinate transformations..." && \
    wget -O /javalibs/sis-referencing-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/core/sis-referencing/${SIS_VERSION}/sis-referencing-${SIS_VERSION}.jar" && \
    wget -O /javalibs/sis-metadata-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/core/sis-metadata/${SIS_VERSION}/sis-metadata-${SIS_VERSION}.jar" && \
    wget -O /javalibs/sis-epsg-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/non-free/sis-epsg/${SIS_VERSION}/sis-epsg-${SIS_VERSION}.jar" && \
    wget -O /javalibs/sis-geotiff-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/storage/sis-geotiff/${SIS_VERSION}/sis-geotiff-${SIS_VERSION}.jar" && \
    wget -O /javalibs/sis-netcdf-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/storage/sis-netcdf/${SIS_VERSION}/sis-netcdf-${SIS_VERSION}.jar" && \
    wget -O /javalibs/sis-earth-observation-${SIS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/sis/storage/sis-earth-observation/${SIS_VERSION}/sis-earth-observation-${SIS_VERSION}.jar" && \
    echo "Downloading JAXB runtime for XML support..." && \
    wget -O /javalibs/jaxb-runtime-4.0.4.jar \
    "https://repo1.maven.org/maven2/org/glassfish/jaxb/jaxb-runtime/4.0.4/jaxb-runtime-4.0.4.jar" && \
    echo "Downloading Apache Derby dependencies for SIS embedded data..." && \
    wget -O /javalibs/derby-${DERBY_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/derby/derby/${DERBY_VERSION}/derby-${DERBY_VERSION}.jar" && \
    wget -O /javalibs/derby-shared-${DERBY_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/derby/derbyshared/${DERBY_VERSION}/derbyshared-${DERBY_VERSION}.jar" && \
    wget -O /javalibs/derbytools-${DERBY_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/derby/derbytools/${DERBY_VERSION}/derbytools-${DERBY_VERSION}.jar" && \
    ls -la /javalibs/ && \
    echo "SIS embedded data and Derby dependencies downloaded"

ENV PATH=$PATH:$SIS_HOME/bin

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

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "-DSIS_DATA=/fuseki-base/SIS_DATA", "-Dorg.apache.sis.referencing.factory.sql.EPSG.embedded=true", "-Dderby.stream.error.file=/fuseki-base/derby-logs/derby.log", "-Dderby.system.home=/fuseki-base/derby-logs", "org.apache.jena.fuseki.main.cmds.FusekiServerCmd"]