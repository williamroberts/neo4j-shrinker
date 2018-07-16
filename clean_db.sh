#!/bin/bash
set -euo pipefail

main() {
  clearArgs && \
    getArgs "$@" && \
    installNeo4j2.1.7 && \
    backupCurrentDatabase && \
    removeOrphanAssetSalesOfferNodes && \
    removeDuplicateAssetSalesOfferNodes && \
    executeCompressionScript
}

clearArgs() {
  unset DB_SRC
  unset DB_DEST
}

getArgs() {
  while getopts "hn:s:d:" opt; do
    case $opt in
      h)
        help
        ;;
      s)
        DB_SRC=$OPTARG
        ;;
      d)
        DB_DEST=$OPTARG
        ;;
      *)
        help
        ;;
    esac
  done
}

installNeo4j2.1.7 () {
  curl --fail --show-error --location https://neo4j.com/artifact.php?name=neo4j-community-2.1.7-unix.tar.gz -o neo4j-community-2.1.7-unix.tar.gz && \
    tar -xf neo4j-community-2.1.7-unix.tar.gz && mv neo4j-community-2.1.7 neo4j-2.1.7 && \
    rm neo4j-community-2.1.7-unix.tar.gz
}

backupCurrentDatabase () {
  echo "Backing up DB from $DB_SRC to $(pwd)..."
  tar -cf "$(basename $DB_SRC).tar" "$DB_SRC"
  echo "Backing up DB from $DB_SRC to $(pwd)... Complete"
}

removeOrphanAssetSalesOfferNodes () {
  echo "Looping though DB to remove orphan AssetSalesOffersNodes..."
  for LOOP in {1..100}
  do
    echo
    echo "Removing Orphan AssetSalesOfferNodes. Loop: $LOOP of 100"
    "./neo4j-2.1.7/bin/neo4j-shell" -path "$DB_SRC" -c "MATCH (n:AssetSalesOffer) WHERE NOT ( (n:AssetSalesOffer)-[]-() ) WITH n LIMIT 500000 DELETE n;"
    sleep 5
  done
  echo "Looping though DB to remove orphan AssetSalesOffersNodes... Complete"
}

removeDuplicateAssetSalesOfferNodes () {
  echo "Removing duplicate AssetSalesOfferNodes..."
  "./neo4j-2.1.7/bin/neo4j-shell" -path "$DB_SRC" -c "MATCH (n:AssetSalesOffer)-[r]-(:AssetSalesHistory)-[]-(a:Asset) WHERE n.bidOrOfferId IS NULL AND a.assetStatus = 'SALES_IN_PROGRESS' DELETE r, n;"
  echo "Removing duplicate AssetSalesOfferNodes... Complete"
}

executeCompressionScript () {
  echo "Exporting the following MAVEN_OPTS for execution of compression script:"
  echo "    -Xmx4G"
  echo "    -Xms4G"
  echo "    -Xmn1G"
  echo "    -XX:+UseG1GC"
  echo "    -XX:+DoEscapeAnalysis"
  echo "    -XX:+UseBiasedLocking"
  echo "    -XX:MaxInlineSize=64"
  echo "    -server"
  echo
  export MAVEN_OPTS="-Xmx4G -Xms4G -Xmn1G -XX:+UseG1GC -XX:+DoEscapeAnalysis -XX:+UseBiasedLocking -XX:MaxInlineSize=64 -server"
  echo "Executing compression script on $DB_SRC and creating new lighter DB at $DB_DEST..."
  mvn compile exec:java -e -Dexec.mainClass="org.neo4j.tool.StoreCopy" -Ddbms.pagecache.memory=2G -Dexec.args="$DB_SRC $DB_DEST" -Dhttps.protocols=TLSv1.2 -Dneo4j.version=2.1.7
  echo "Executing compression script on $DB_SRC and creating new lighter DB at $DB_DEST... Complete"
}

help () {
  SCRIPT_NAME="$(basename -- "$0")"
  echo "Description:"
  echo "Cleans up the Neo4j DB"
  echo ""
  echo "Example:"
  echo ""
  echo "./$SCRIPT_NAME -s /home/mijo/neo4j/assets -d /home/mijo/neo4j/assets_light"
  echo ""
  echo "------------------------------------------------------------------------------------------------------------------"
  echo "| # | Arguments | Description                                                                                    |"
  echo "|---|-----------|------------------------------------------------------------------------------------------------|"
  echo "| 1 |    -s     | (Required) The path to the source DB folder e.g. /home/mijo/neo4j/assets                       |"
  echo "|---|-----------|------------------------------------------------------------------------------------------------|"
  echo "| 2 |    -d     | (Required) Use to skip tests during the Maven build. e.g /home/mijo/neo4j/assets_light         |"
  echo "------------------------------------------------------------------------------------------------------------------"
  echo ""
  exit 0
}

main "$@"
