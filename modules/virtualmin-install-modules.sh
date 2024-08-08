#!/bin/sh

# Set the path
pwd="${pwd:-.}"

# Source individual Virtualmin install modules
# shellcheck disable=SC1091
# shellcheck source=virtualmin-install-module-s3-scheduled-backups.sh
. "$pwd/virtualmin-install-module-s3-scheduled-backups.sh"
