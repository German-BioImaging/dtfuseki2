sudo docker run --rm -v $PWD/data:/fuseki-base/databases -v $PWD:/src:ro --entrypoint=bash fusekidocker_fuseki /src/load.sh
