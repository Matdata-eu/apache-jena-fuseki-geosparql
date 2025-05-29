# Docker container for Apache Jena Fuseki with GeoSPARQL support

[![Docker Pulls](https://img.shields.io/docker/pulls/mathiasvda/apache-jena-fuseki-geosparql.svg)](https://hub.docker.com/r/mathiasvda/apache-jena-fuseki-geosparql)
[![Docker Stars](https://img.shields.io/docker/stars/mathiasvda/apache-jena-fuseki-geosparql.svg)](https://hub.docker.com/r/mathiasvda/apache-jena-fuseki-geosparql)
[![Docker Image Size](https://img.shields.io/docker/image-size/mathiasvda/apache-jena-fuseki-geosparql/latest.svg)](https://hub.docker.com/r/mathiasvda/apache-jena-fuseki-geosparql)

## Description

This Docker container provides Apache Jena Fuseki with built-in GeoSPARQL support, enabling spatial queries on RDF data. It includes:

- **Apache Jena Fuseki 5.4.0** - A robust SPARQL server and query engine
- **GeoSPARQL Extension** - Support for spatial data queries and geometric operations
- **Full-text Search** - Lucene-based text indexing for enhanced search capabilities
- **TDB Storage** - High-performance triple store with union default graph
- **Security** - Apache Shiro authentication with configurable admin access

### Features

- 🌍 **Spatial Queries**: GeoSPARQL 1.0 support for geometric and topological operations
- 🔍 **Text Search**: Integrated Lucene indexing for SKOS labels and RDF literals
- 📊 **High Performance**: TDB storage with optimized configurations
- 🔐 **Secure**: Built-in authentication with configurable admin password
- 🐳 **Docker Ready**: Production-ready container with proper security settings
- 📡 **REST API**: Complete SPARQL endpoint with read/write capabilities
- 🔄 **Data Loading**: Pre-configured tools for efficient data import

More information about the GeoSPARQL implementation of Apache Jena Fuseki can be found in the [official documentation](https://jena.apache.org/documentation/geosparql/).

Limitation: coordinate transformations are currently an issue. Distance calculation seems to be related to this. This probably has something to do with SIS_DATA.

## Usage

### Quick Start

A docker image is available on [Docker Hub](https://hub.docker.com/r/mathiasvda/apache-jena-fuseki-geosparql).

```bash
# Run with default settings (port 3030)
docker run -p 3030:3030 mathiasvda/apache-jena-fuseki-geosparql

# Run with persistent data storage
docker run -p 3030:3030 -v /path/to/data:/fuseki-base mathiasvda/apache-jena-fuseki-geosparql
```

### Accessing the Service

Once running, you can access:

- **Fuseki Web UI**: http://localhost:3030

### Docker Compose Example

```yaml
version: "3.8"
services:
  fuseki-geosparql:
    image: mathiasvda/apache-jena-fuseki-geosparql:latest
    ports:
      - "3030:3030"
    volumes:
      - fuseki_data:/fuseki-base
    restart: unless-stopped

volumes:
  fuseki_data:
```

### Loading Data

You can load RDF data into the container using several methods:

#### 1. Using the Web UI

You can access the Fuseki Web UI at `http://localhost:3030` to upload your RDF data files directly.

#### 2. Using Docker Volume Mounts

```bash
# Mount your data directory and use tdbloader
docker run -v /path/to/your/data:/data -v fuseki_data:/fuseki-base \
  mathiasvda/apache-jena-fuseki-geosparql \
  bash -c 'eval $TDBLOADER /data/*.ttl && java -cp "*:/javalibs/*" org.apache.jena.fuseki.main.cmds.FusekiServerCmd'
```

#### 3. Using SPARQL Graph Store Protocol

```bash
# Upload a file via HTTP
curl -X POST -H "Content-Type: text/turtle" \
  --data-binary @your-data.ttl \
  http://localhost:3030/ds/data
```

#### 4. Using SPARQL UPDATE

```bash
# Insert triples via SPARQL UPDATE (requires ENABLE_UPDATE=true)
curl -X POST -H "Content-Type: application/sparql-update" \
  --data "INSERT DATA { <http://example.org/subject> <http://example.org/predicate> <http://example.org/object> }" \
  http://localhost:3030/ds/update
```

### GeoSPARQL Queries

Example spatial queries you can run:

```sparql
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>
PREFIX uom: <http://www.opengis.net/def/uom/OGC/1.0/>

# Test basic GeoSPARQL geometry functions without UOM
SELECT ?test_name ?point ?buffer_geom ?envelope_geom WHERE {

  VALUES (?test_name ?lat ?lon ?buffer_distance) {
    ("Amsterdam Central" 52.3791 4.9003 0.01)
    ("Rotterdam Port" 51.9225 4.4792 0.02)
    ("Utrecht Center" 52.0907 5.1214 0.015)
  }
    # Create point geometry from coordinates
  BIND(STRDT(CONCAT("<http://www.opengis.net/def/crs/EPSG/0/4326> POINT(", STR(?lon), " ", STR(?lat), ")"), geo:wktLiteral) AS ?point)

  # Create a buffer around the point (simple circular buffer)
  BIND(geof:buffer(?point, ?buffer_distance, uom:degree) AS ?buffer_geom)

  # Get the envelope (bounding box) of the buffered geometry
  BIND(geof:envelope(?buffer_geom) AS ?envelope_geom)
}
ORDER BY ?test_name
```

```sparql
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>

# Test GeoSPARQL spatial relationships without UOM namespace
# This query tests contains, intersects, and within relationships
SELECT ?relation ?geometry1_label ?geometry2_label ?result WHERE {

  # Define test geometries
  VALUES (?geometry1_label ?geometry1 ?geometry2_label ?geometry2 ?relation) {
    # Point within polygon test
    ("City Center" "POINT(4.9041 52.3676)"^^geo:wktLiteral "Amsterdam Bounds" "POLYGON((4.8 52.3, 5.0 52.3, 5.0 52.4, 4.8 52.4, 4.8 52.3))"^^geo:wktLiteral "within")

    # Line intersects polygon test
    ("Highway" "LINESTRING(4.85 52.32, 4.95 52.38)"^^geo:wktLiteral "Amsterdam Bounds" "POLYGON((4.8 52.3, 5.0 52.3, 5.0 52.4, 4.8 52.4, 4.8 52.3))"^^geo:wktLiteral "intersects")

    # Polygon contains point test
    ("Large Area" "POLYGON((4.7 52.2, 5.1 52.2, 5.1 52.5, 4.7 52.5, 4.7 52.2))"^^geo:wktLiteral "Small Point" "POINT(4.9 52.35)"^^geo:wktLiteral "contains")

    # Buffer test (point with buffer intersects line)
    ("Station" "POINT(4.9 52.37)"^^geo:wktLiteral "Train Line" "LINESTRING(4.88 52.36, 4.92 52.38)"^^geo:wktLiteral "intersects")
  }

  # Test the spatial relationship based on the relation type
  BIND(
    IF(?relation = "within", geof:sfWithin(?geometry1, ?geometry2),
    IF(?relation = "intersects", geof:sfIntersects(?geometry1, ?geometry2),
    IF(?relation = "contains", geof:sfContains(?geometry1, ?geometry2),
    false))) AS ?result
  )
}
ORDER BY ?relation ?geometry1_label
```

## Building from Source

```bash
# Clone the repository
git clone https://github.com/matdata-eu/apache-jena-fuseki-geosparql.git
cd apache-jena-fuseki-geosparql

# Build the Docker image
docker build -t apache-jena-fuseki-geosparql .

# Run your custom build
docker run -p 3030:3030 apache-jena-fuseki-geosparql
```

or use the provided `docker-compose.yml` file:

```bash
docker-compose up --build
```

## Configuration

The container uses several configuration files in the `config/` directory:

- `assembler.ttl` - Dataset and service configuration
- `fuseki-config.ttl` - Server-wide settings and timeouts
- `shiro.ini` - Security and authentication configuration
- `docker-entrypoint.sh` - Container initialization script

You can override these by mounting your own configuration files:

```bash
docker run -p 3030:3030 \
  -v ./my-assembler.ttl:/fuseki-base/configuration/assembler.ttl \
  mathiasvda/apache-jena-fuseki-geosparql
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure your data volumes have proper permissions (the container runs as user 9008)
2. **Memory Issues**: Increase Docker memory allocation for large datasets
3. **Connection Refused**: Check that you're using the correct port (3030, not 8080)

### Logs

```bash
# View container logs
docker logs <container-name>

# Follow logs in real-time
docker logs -f <container-name>
```

### Health Check

```bash
# Check if Fuseki is responding
curl -f http://localhost:3030/$/ping
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## LICENSE

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
