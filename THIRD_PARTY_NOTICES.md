# Third-party notices

The apache-jena-fuseki-geosparql Docker image is © 2026 Mathias Vanden Auweele
([Matdata](https://matdata.eu/)). The files in this repository are licensed
under the [Apache License 2.0](LICENSE). Questions, bug reports and feature
requests: <https://github.com/Matdata-eu/apache-jena-fuseki-geosparql/issues>.

The image redistributes the third-party software below, unmodified. Each JAR
in `/javalibs` keeps its own `META-INF/LICENSE` and `META-INF/NOTICE` files,
which hold the full license texts and notices.

| Component | License | Notes |
| --- | --- | --- |
| [Apache Jena](https://jena.apache.org/) (Fuseki, GeoSPARQL, ARQ, TDB, text) and its Maven dependencies | Apache-2.0 | Downloaded by Maven at build time into `/javalibs` |
| [Apache SIS](https://sis.apache.org/) (`sis-referencing`) | Apache-2.0 | |
| [EPSG Geodetic Parameter Dataset](https://epsg.org/), via Apache SIS `sis-embedded-data` | [EPSG terms of use](https://epsg.org/terms-of-use.html) | Not open source: free to use and redistribute, but distribution for profit is forbidden. The terms are in the JAR's `META-INF/LICENSE`. |
| [Apache Derby](https://db.apache.org/derby/) (used by `sis-embedded-data`) | Apache-2.0 | |
| [Eclipse Temurin](https://adoptium.net/) 21 JRE (base image) | GPL-2.0 with Classpath Exception | See `/opt/java/openjdk/legal` in the image |
| [Alpine Linux](https://alpinelinux.org/) packages (base image, bash, Maven, jq, ruby, …) | Various open source licenses | See each package's metadata (`apk info -L`) |

The Dockerfile, entrypoint and Fuseki configuration are based on
[SemanticComputing/fuseki-docker](https://github.com/SemanticComputing/fuseki-docker),
which is inspired by [stain/jena-docker](https://github.com/stain/jena-docker).
Those files carry the Apache Software Foundation's Apache-2.0 license header.

