# pt-magic-scripts
This repository contains a number of bash scripts I use to manage PT Magic (PTM) on my VPS running on Ubuntu 17.10. PT Magic is an add-on to Profit Trailer (PT).

This repository contains the following scripts:
1. Deploy script (deploy-scripts.sh)
2. PTM upgrade (ptm-upgrade.sh)
3. PTM deploy presets (ptm-deploy-presets.sh)

What the scripts do is described in the following sections.

# 1. Deploy scripts (deploy-scripts.sh)

This script deploys the scripts to each PT Magic (PTM) instances, so each instance has the latest versions of the scripts. This means you can use git clone and pull to keep the scripts up to date. When a new version is available, just do a pull to sync and then call this script to deploy it to each PTM instances.

## What does it do?

The script does the following:

* It retrieves all the  symbolic links from the /op/pt-magic directory that end with \'-cur\'
* It publishes all scripts to the directories the symbolic links are pointing to
* It makes the main scripts executable

## Important

This script is based on my setup of [Ubuntu](http://nidkil.me/2018/01/19/initial-server-setup-ubuntu-17-10/), [Profit Trailer](http://nidkil.me/2018/01/22/profittrailer-setup-on-ubuntu-17-10/) and [PT Magic](http://nidkil.me/2018/02/19/pt-magic-setup-on-ubuntu-17-10/).

* This script expects that the following directory layout is used:

    | Directory                          | Description                                  |
    | ---------------------------------- | -------------------------------------------- |
    | /opt/pt-magic/ptm-\<exchange\>-cur | softlink pointing to the current PTM version |
  
Where \<exchange\> is the exchange the PTM installation is for.

## Command line arguments

Usage: publish-scripts.sh

Example: publish-scripts.sh

# 2. PTM upgrade (ptm-upgrade.sh)

Upgrades a PT Magic (PTM) instance to the latest version. It downloads the latest version of PTM from GitHub and installs it to a new directory with existing data and config files. This script must be run from inside the directory of the current PTM instance you wish to upgrade. If the latest version is already installed it will display a warning message and exit.

## What does it do?

The script does the following:

* Checks if a new version of PTM is available on GitHub
* If a new version is available it downloads it
* Stops PTM and PTM Monitor using PM2
* Makes a copy of the current PTM installation to a new directory so that the data and configs are maintained, this makes it possible to rollback to the old version if necessary
* Installs the downloaded version of PTM in the new directory
* Sets a softlink (ptm-\<exchange\>-cur) to the new directory, so that it becomes the current version
* Removes the PM2 settings, as these are pointing to the old PTM directory
* Restarts PTM and PTM Monitor with PM2

## Important

This script is based on my setup of [Ubuntu](http://nidkil.me/2018/01/19/initial-server-setup-ubuntu-17-10/), [Profit Trailer](http://nidkil.me/2018/01/22/profittrailer-setup-on-ubuntu-17-10/) and [PT Magic](http://nidkil.me/2018/02/19/pt-magic-setup-on-ubuntu-17-10/).

1) This script expects that the following directory layout is used:

    | Directory                          | Description                                  |
    | ---------------------------------- | -------------------------------------------- |
    | /opt/pt-magic/ptm-\<exchange\>-cur | softlink pointing to the current PTM version |
  
2) It also expects that PM2 is used to manage PTM and process identifiers conform with the following naming convention:

    | Naming convention     | Description       |
    | --------------------- | ----------------- |
    | ptm-\<exchange\>      | PT Magic          |
    | ptm-mon-\<exchange\>  | PT Magic Monitor  |
  
Where \<exchange\> identifies the exchange the PTM instance is for.

The script will extract the unique exchange identifier from the directory name it is executed from.

## Command line arguments

Usage: ptm-update.sh [-d]

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;optional arguments:
  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-d  show initialized variables and exit the script, for debugging purposes

Example: ptm-update.sh

# 3. PTM deploy presets (ptm-deploy-presets.sh)

Presets have to be updated under both the PTM _presets directory and the PT directory. It is very inconventient to do this manually. This script publishes presets to both directories in one go.

This script takes properties files placed in a specific directory and deploys them to both Profit Trailer (PT) and PT Magic (PTM). To do this safely it stops and restarts PT and PTM. This script must be run from the PTM instance directory. It expects there is a subdirectory called \'_deploy\' that contains the PAIRS.properties, DCA.properties and INDICATOR.properties you wish to deploy. Once the properties files have been copied it will restart PT and PTM. The existing properties files will be backed up to a unique subdirectory under the directory called 'backup' just in case a rollback is required.

## What does it do?

The script does the following:

* Stops PT and PTM
* Backs up existing properties files to a unique directory under the subdirectory backup in both PT and PTM directories
* Copies the properties files to both PT and PTM
* Restarts PT and PTM

## Important

This script is based on my setup of [Ubuntu](http://nidkil.me/2018/01/19/initial-server-setup-ubuntu-17-10/), [Profit Trailer](http://nidkil.me/2018/01/22/profittrailer-setup-on-ubuntu-17-10/) and [PT Magic](http://nidkil.me/2018/02/19/pt-magic-setup-on-ubuntu-17-10/).

1) This script expects that the following directory layout is used:

    | Directopry                              | Description                                                                    |
    | --------------------------------------- | ------------------------------------------------------------------------------ |
    | /opt/pt-magic/ptm-\<exchange\>-cur      | softlink pointing to the current PTM version                                   |
    | /opt/profit-trailer/pt-\<exchange\>-cur | softlink pointing to the current PT version that the PTM instance is linked to |
  
2) It also expects that PM2 is used to manage PT and PTM and process identifiers conform with the following naming convention:

    | Naming convention     | Description       |
    | --------------------- | ----------------- |
    | pt-\<exchange\>       | Profit Trailer    |
    | ptm-\<exchange\>      | PT Magic          |
    | ptm-mon-\<exchange\>  | PT Magic Monitor  |

3) Currently only supports a single preset file setup for PTM

Where \<exchange\> identifies the exchange the PT and PTM instances are for.

The script will extract the unique exchange identifier from the directory name it is executed from.

## Command line arguments

Usage: ptm-presets-deploy.sh [-d]

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;optional arguments:
  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-d  show initialized variables and exit the script, for debugging purposes

Example: ptm-presets-deploy.sh

# Done

The following has been implemented:

* Automated the upgrade to the latest version of PTM
* Automated the deployment of presets to PT and PTM in one go

# To do

The following still needs to be implemted:

* Support for multiple instances per exchange (test, production, sell only)
* Support for multiple presets per instance

I hope this is helpful for someone else. If you have any tips how to improve the scripts or any other suggestions drop me a message.
