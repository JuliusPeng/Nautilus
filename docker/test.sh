#!/bin/bash
#
# Master script to build and run conseil, postgres, and tezos containers and their respective volumes.


# global constants
CMD="$(basename $0)"

# utility functions used by this script
error () { echo "error: $@" >&2; }
fatal () { echo "fatal: $@" >&2; exit 1; }
display_usage () {
    cat <<EOF


Connections to the imaging pi/instance/droplet are made using SSH.  Docker has to be preinstalled and ports 1337, 5432,
8732, 9732, and 19732 will be opened.

This script was written to be executed from Jenkins, but can also be run locally.
If executing from Jenkins, be sure to create a "jenkins" user on the remote imaging pi/instance/droplet and
add the jenkins user public key as an authorized key.
If executing locally, be sure to change the postgres username and password in conseil.conf located in
docker/config/local/conseil/ and use the same username and password in dockerfile for postgres.

Usage: $CMD [OPTIONS] -p [/PATH/TO/CONFIG_FOLDER]]
            [-h] [-v]

Options:
    -a, --all                      builds, links, and starts tezos, postgres, and conseil docker
                                   containers and their respective volumes
    -b, --build-name               if specified, creates a name for current build, otherwise
                                   defaults to current time
    -c, --conseil                  stops and removes existing conseil container if it exists
                                   and rebuilds and starts a new instance of the conseil container
    -d, --database                 stops and removes existing postgres database container if it exists
                                   and rebuilds only the postgres container
    -h, --help                     display this help and exit
    -n, --protocol                 tezos network("mainnet", "zeronet", "alphanet") if not specified defaults to alphanet
    -p, --path_to_config           absolute path to configuration folder, folder should contain at the very least a conseil folder,
                                   if using a modified schema, a postgres folder with a conseil.sql file. if not specified,
                                   uses configuration files for conseil, postgres and tezos from the config folder in repo.
                                   config folder name will also be used in docker container nomenclature(e.g. config folder name is
                                   prod1, docker container name will be conseil-prod1, postgres-prod1, etc.),default config folder is
                                   "local", it resides within config folder in repo
                                   NOTE: docker volumes will be created here to create persistence
    -t, --tezos                    stops and removes existing tezos container if it exists
                                   and rebuilds and starts the tezos container
    -v, --volume                   REMOVES postgres volume and postgres volume folder, use at own risk as this will
                                   require all blocks to be replaced in the postgres database, this is necessary if
                                   there has been a schema change as simply rebuilding the container will not replace the schema

Examples:
    $CMD -a -p /home/production-environment-1
                                   # build, initialize, and run docker containers
                                   # for conseil, postgres, and tezos
                                   # takes config files from production-environment-1 folder


Report bugs to <swap@cryptonomic.tech>.
EOF
}

# parse command line arguments
SHORT_OPTS='ab:cd:hn:p:tv'
LONG_OPTS='all,build-name:,conseil,database,help,path-to-config:,protocol:,tezos,volume'
ARGS=$(getopt -o $SHORT_OPTS -l $LONG_OPTS -n "$CMD" -- "$@" 2>/dev/null)
#check getopt command failure
(( $? != 0 )) && fatal "invalid options"
eval set -- "$ARGS"
# set execution flags and/or execute functions for each option
while true ; do
    case "$1" in
        -h|--help) display_usage && exit 0 ; shift ;;
        -a|--all) CONSEIL=1 ; POSTGRES=1 ; TEZOS=1 ; shift ;;
        -b|--build-name) build_name="$2" ; shift 2 ;;
	    -c|--conseil) CONSEIL=1 ; shift ;;
        -d|--database) POSTGRES=1 ; shift ;;
        -h|--help) display_usage && exit 0 ; shift ;;
        -n|--protocol) protocol="$2" ; shift 2 ;;
        -p|--path-to-config) path_to_config="$2" ; shift 2 ;;
        -t|--tezos) TEZOS=1 ; shift ;;
        -v|--volume) VOLUME=1 ; shift ;;
        --) shift ; break ;;
    esac
done

