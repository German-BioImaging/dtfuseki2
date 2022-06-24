#!/bin/bash

set -e
set -x


# sudo docker run --rm -v $PWD:/src/:ro -v $PWD...data --entrypoint=bash $IMAGE src/load.sh

URI=http://idr.semscape.org:3030/
$TDBLOADER --graph=$URI/hpa $FUSEKI_BASE/databases/hpa_omero.ttl.gz
$TEXTINDEXER
$TDBSTATS --graph urn:x-arq:UnionGraph > /tmp/stats.opt
mv /tmp/stats.opt $FUSEKI_BASE/databases/tdb/
