#!/bin/bash

# Get the current directory, the -P means if it is a symbolic link then follow it to the source directory
ORIG_DIR=$(pwd -P)
CUR_DIR=$(pwd)

source $CUR_DIR/helper-scripts/helpers.sh

# Get the parent directory of the current directory
PARENT_DIR=`dirname $ORIG_DIR`
# Strip the version number from the current directory
BASE_PATH=${ORIG_DIR%-v*}
CUR_INSTALLED=${ORIG_DIR#*-v}
# Setup some constants
PT_ROOT_DIR="profit-trailer"
PTM_ROOT_DIR="pt-magic"
PTM_DEPLOY_DIR="_deploy"
PT_CFG_DIR="trading"
PTM_CFG_DIR="_presets/Default"
BCK_DIR="backup"
# Use parameter expansion to extract the exchange identifier
EXCHANGE=${BASE_PATH##*/ptm-}
# Use parameter expansion to extract the final directory from the path
DIR_ONLY=${CUR_DIR##*/}

# Get the latest PT Magic release
LATEST_RELEASE=$(get_latest_release "Legedric/ptmagic")

# Lets make sure we have a version number with 'v' and without
VERSION=$LATEST_RELEASE
if [[ ${VERSION:0:1} != "v" ]]; then
	VERSION_NUM=$VERSION
	VERSION="v$VERSION"
else
	POS=$((${#VERSION} - 1))
	VERSION_NUM=${VERSION:1:$POS}
fi

# Create the download link
BASE_URL="https://github.com/Legedric/ptmagic/releases/download"
FILE_NAME="PTMagic.$VERSION_NUM.zip"
URL="$BASE_URL/$VERSION_NUM/$FILE_NAME"

PM2_PMT_FILE="pm2-PTMagic.json"
PM2_PMT_MON_FILE="pm2-PTM-Monitor.json"
PM2_PMT=$(get_pm2_id $PM2_PMT_FILE)
PM2_PMT_MON=$(get_pm2_id $PM2_PMT_MON_FILE)

handle_error() {
    echo ""
    echo "Upgrades a PT Magic (PTM) instance to the latest version. It downloads the latest version"
    echo "of PTM from GitHub and installs it to a new directory with existing data and config files."
	echo "This script must be run from inside the directory of the current PTM instance you wish to"
	echo "upgrade. If the latest version is already installed it will display a warning message and"
	echo "exit."
    echo ""
    echo "IMPORTANT:"
    echo ""
	echo "1) This script expects that the following directory layout is used:"
    echo ""
    echo "  /opt/pt-magic/ptm-<exchange>-cur  softlink pointing to the current PTM version"
    echo ""
	echo "2) It also expects that PM2 is used to manage PTM and process identifiers conform with the"
	echo "   following naming convention:"
    echo ""
    echo "  - ptm-<exchange>      PT Magic"
    echo "  - ptm-mon-<exchange>  PT Magic Monitor"
    echo ""
    echo "Where <exchange> identifies the exchange the PTM instance is for."
    echo ""
	echo "The script will extract the unique exchange identifier from the directory name it is executed "
	echo "from."
	echo ""
    echo "Usage: ptm-upgrade.sh -d"
    echo ""
    echo " -d  show initialized variables and exit script, for debugging purposes"
    echo ""
    echo "Example: ptm-upgrade.sh"
    echo ""
    exit
}

debug_info() {
	echo ""
	echo " ------------------- DEBUG INFO ----------"
	echo ""
	echo "    ORIG_DIR       : $ORIG_DIR"
	echo "    CUR_DIR        : $CUR_DIR"
	echo "    PARENT_DIR     : $PARENT_DIR"
	echo "    BASE_PATH      : $BASE_PATH"
	echo "    PT_ROOT_DIR    : $PT_ROOT_DIR"
	echo "    PT_CFG_DIR     : $PT_CFG_DIR"
	echo "    PTM_ROOT_DIR   : $PTM_ROOT_DIR"
	echo "    PTM_DEPLOY_DIR : $PTM_DEPLOY_DIR"
	echo "    PTM_CFG_DIR    : $PTM_CFG_DIR"
	echo "    BCK_DIR        : $BCK_DIR"
	echo "    EXCHANGE       : $EXCHANGE"
	echo "    DIR_ONLY       : $DIR_ONLY"
	echo ""
	echo "    CUR_INSTALLED  : $CUR_INSTALLED"
	echo "    LATEST_RELEASE : $LATEST_RELEASE"
	echo "    VERSION        : $VERSION"
	echo "    VERSION_NUM    : $VERSION_NUM"
	echo ""
	echo "    BASE_URL       : $BASE_URL"
	echo "    FILE_NAME      : $FILE_NAME"
	echo "    URL            : $URL"
	echo ""
	echo "    PM2_PMT        : $PM2_PMT"
	echo "    PM2_PMT_MON    : $PM2_PMT_MON"
	echo ""
	echo " ------------------- DEBUG INFO ----------"
	echo ""
	exit
}

if [ $# -ne 0 ]; then
	if [[ $# -gt 1 ]]; then
		print_err "Error: Incorrect number of parameters, found $# but expected 1"
		handle_error	
	elif [[ $# -eq 1 && "$1" = "-d" ]]; then
		debug_info
	else
		print_err "Error: Unknown parameters [$1]"
		handle_error
	fi
fi

if [[ ("$DIR_ONLY" != "ptm-"*) || ("$DIR_ONLY" != *"-cur") ]]; then
    print_err "Error: this script must be executed from the active (current) version of PTM"
    handle_error
fi

if [[ "$CUR_INSTALLED" = "$LATEST_RELEASE" ]]; then
	echo -e "${Cyan}Latest version is already installed${Color_Off}"
	exit
else
	echo "There is a new release available [$LATEST_RELEASE]"
fi

echo "Checking if url exists [$URL]"
STATUS=$(curl -s --head -w %{http_code} $URL -o /dev/null)
if [[ $STATUS -ne 200 && $STATUS -ne 302 ]]; then
    print_err "Error: URL not found [code=$STATUS, URL=$URL]"
    print_err "       Check the version number [version=$VERSION]"
    handle_error
fi

read -p "Are you sure you want to update to version ${LATEST_RELEASE} [yN]?" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit
fi

TMP_DIR="tmp"
WORK_DIR="$PARENT_DIR/ptm-$EXCHANGE-$VERSION"
OLD_DIR=""

if [[ "$CUR_DIR" == "$WORK_DIR" ]]; then
    print_err "Current directory and working directory are the same [$WORK_DIR]"
	handle_error
else
    echo "Checking if working directory exists [$WORK_DIR]"
    EXISTS=$(dir_exists $WORK_DIR false)

    if [[ "$EXISTS" == "false" ]]; then
        echo "Creating working directory [$WORK_DIR]"
        OLD_DIR=$CUR_DIR
        mkdir -p $WORK_DIR
	else
        echo -e "${Cyan}WARNING: Working directory exists [$WORK_DIR], delete it if you want to continue${Color_Off}"
		exit
    fi
    
    echo "Changing to working directory [$WORK_DIR]"
    cd $WORK_DIR
    CUR_DIR=`pwd`
fi

echo "Downloading zip file from URL [$URL]"
download $URL .
echo "Unzipping zip file to temporary directory [$TMP_DIR]"
unzip -q *.zip -d ./$TMP_DIR

echo "Stopping PT Magic & PTM Monitor"
pm2 stop $PM2_PMT $PM2_PMT_MON

echo "Copying previous version [$OLD_DIR to `pwd`]"
cp -R $OLD_DIR/* .

MOVE_FROM="./$TMP_DIR/PTMagic ${VERSION_NUM}/PTMagic"
echo "Moving files from temporary directory [$MOVE_FROM] to main directory [$CUR_DIR]"
cp -rf "$MOVE_FROM"/* .

echo "Cleaning up: deleting zip file, tmp directory and debug file"
rm *.zip debug.log
rm -rf $TMP_DIR

echo "Changing the softlink to the new version [$BASE_PATH-cur]"
rm $BASE_PATH-cur
ln -s $CUR_DIR $BASE_PATH-cur

echo "Ready to startup the new version"

echo "Switch to new directory"
cd $CUR_DIR

echo "Delete PT Magic & PTM Monitor, so link with old version is broken"
pm2 delete $PM2_PMT $PM2_PMT_MON

echo "Starting new version of PT Magic & PTM Monitor"
pm2 start $PM2_PMT_FILE $PM2_PMT_MON_FILE

echo "All done, let's rock!"
