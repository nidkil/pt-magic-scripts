#!/bin/bash

# Get the current directory, the -P means if it is a symbolic link then follow it to the source directory
ORIG_DIR=$(pwd -P)
CUR_DIR=$(pwd)
# Get the parent directory of the current directory
PARENT_DIR=`dirname $ORIG_DIR`
# Strip the version number from the current directory
BASE_DIR=${ORIG_DIR%-v*}
# Setup some constants
PT_ROOT_DIR="profit-trailer"
PTM_ROOT_DIR="pt-magic"
DEPLOY_DIR="_deploy"
PT_CFG_DIR="trading"
PTM_CFG_DIR="_presets/Default"
BCK_DIR="backup"
# Use parameter expansion to extract the exchange identifier
EXCHANGE=${BASE_DIR##*/ptm-}
# Use parameter expansion to extract the final directory from the path
DIR_ONLY=${CUR_DIR##*/}

source $ORIG_DIR/helper-scripts/helpers.sh

handle_error() {
    echo ""
    echo "This script takes properties files placed in a specific directory and deploys them to both"
	echo "Profit Trailer (PT) and PT Magic (PTM). To do this safely it stops and restarts PT and PTM."
	echo "This script must be run from the PTM directory. It expects there is a subdirectory called"
	echo "'_deploy' that contains the PAIRS.properties, DCA.properties and INDICATOR.properties you"
	echo "wish to deploy. Once the properties files have been copied it will restart PT and PTM. The"
	echo "existing properties files will be backed up to a unique subdirectory under the directory"
	echo "called 'backup' just in case a rollback is required."
    echo ""
    echo "IMPORTANT:"
    echo ""
	echo "1) This script expects that the following directory layout is used:"
    echo ""
    echo "  /opt/pt-magic/ptm-<exchange>-cur       softlink pointing to the current PTM version"
    echo "  /opt/profit-trailer/pt-<exchange>-cur  softlink pointing to the current PT version that"
	echo "                                         the PTM instance is linked to"
    echo ""
	echo "2) It also expects that PM2 is used to manage PTM and process identifiers conform with the"
	echo "   following naming convention:"
    echo ""
    echo "  - pt-<exchange>       Profit Trailer"
    echo "  - ptm-<exchange>      PT Magic"
    echo "  - ptm-mon-<exchange>  PT Magic Monitor"
    echo ""
	echo "3) Currently only supports a single preset file setup for PTM"
    echo ""
    echo "Where <exchange> identifies the exchange the PT and PTM instances are for"
    echo ""
	echo "The script will extract the unique exchange identifier from the directory name it is executed"
	echo "from."
	echo ""
    echo "Usage: deploy-presets-deploy.sh"
    echo ""
    echo "Example: deploy-presets-deploy.sh"
    echo ""
    exit
}

if [[ ("$DIR_ONLY" != "ptm-"*) || ("$DIR_ONLY" != *"-cur") ]]; then
    print_err "Error: this script must be executed from the active (current) version of PTM"
    handle_error
fi

echo "Executing for exchange: $EXCHANGE"

PT_DIR="$PARENT_DIR/pt-$EXCHANGE-cur"
PT_DIR="${PT_DIR/$PTM_ROOT_DIR/$PT_ROOT_DIR}"
PTM_DIR="$PARENT_DIR/ptm-$EXCHANGE-cur"
PM2_PT="pt-$EXCHANGE"
PM2_PTM="ptm-$EXCHANGE"
PM2_PTM_MON="pt-mon-$EXCHANGE"

echo "With settings: PT_DIR=$PT_DIR, PTM_DIR=$PTM_DIR, PM2_PT=$PM2_PT, PM2_PTM=$PM2_PTM, PM2_PTM_MON=$PM2_PTM_MON"

RESULT=$(dir_exists $PT_DIR)
if [ "$RESULT" == "false" ]; then
    print_err "Error: the PT directory does not exist [$PT_DIR]"
    exit
fi

RESULT=$(dir_exists $PTM_DIR)
if [ "$RESULT" == "false" ]; then
    print_err "Error: the PTM directory does not exist [$PTM_DIR]"
    exit
fi

RESULT=$(dir_exists $DEPLOY_DIR)
if [ "$RESULT" == "false" ]; then
    print_err "Error: the deploy directory does not exist [$DEPLOY_DIR]"
    exit
fi

echo "Stopping PT [$PT_DIR]"
stop_pt $PT_DIR

echo "Stopping PT and PTM Monitor"
pm2 stop $PM2_PTM $PM2_PTM_MON

echo "Backing up current configurations"

BCK_SUBDIR=$(unique_bck_dir $BCK_DIR)

PT_BCK_DIR=$PT_DIR/$BCK_DIR/$BCK_SUBDIR
echo "Backing up PT [$PT_BCK_DIR]"
mkdir -p $PT_BCK_DIR
cp $PT_CFG_DIR/* $PT_BCK_DIR/.
cp configuration.properties $PT_BCK_DIR/.
cp application.properties $PT_BCK_DIR/.

PTM_BCK_DIR=$PT_DIR/$BCK_DIR/$BCK_SUBDIR
echo "Backing up PTM default presets [$PTM_BCK_DIR]"
mkdir -p $PTM_BCK
cp $PTM_CFG_DIR/* $PTM_BCK_DIR/.

echo "Deploying new configuration"

PT_DPLY_TO_DIR=$PT_DIR/$PT_DPLY_DIR
echo "Deploying to PT [from $DEPLOY_DIR to $PT_DPLY_TO_DIR]"
cp -f $DEPLOY_DIR/* $PT_DPLY_TO_DIR/.

PTM_DPLY_TO_DIR=$PTM_DIR/$PTM_CFG_DIR
echo "Deploying to PTM [from $DEPLOY_DIR to $PTM_DPLY_TO_DIR]"
cp -f $DEPLOY_DIR/* $PTM_DPLY_TO_DIR/.

echo "Cleaning up"
rm $DEPLOY_DIR/*.properties

echo "Restarting PT and PTM for: $EXCHANGE"
pm2 start $PM2_PT $PM2_PTM $PM2_PTM_MON