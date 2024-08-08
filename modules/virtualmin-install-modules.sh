#!/bin/sh

# Copyright 2005-2024 Virtualmin
# Simple script to call individual Virtualmin install modules

# Set the path
pwd="${pwd:-.}"

# Source individual Virtualmin install modules
# shellcheck disable=SC1091
# shellcheck source=virtualmin-install-module-s3-scheduled-backups.sh
. "$pwd/virtualmin-install-module-s3-scheduled-backups.sh"
