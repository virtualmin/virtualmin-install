## Virtualmin Install Modules

This directory contains modules to run in Virtualmin post-installation process
to configure specific tasks.

### Script Details

#### virtualmin-install-modules.sh

Main script to orchestrate different scripts in the setup process. This script
sources the individual configuration scripts.

#### virtualmin-install-module-s3-scheduled-backups.sh

Script to configure AWS S3 and Virtualmin scheduled backups. This script
configures AWS S3 and Virtualmin scheduled backups with given S3 bucket details.

##### Script Parameters
Parameters can be set as environment variables.

Required parameters are:

- `S3KEY`: S3 access key
- `S3SEC`: S3 secret key
- `S3RGN`: S3 region

Optional parameters are:

- `S3END`: S3 endpoint (for compatibility with other S3-compatible services)
- `S3NAM`: S3 bucket name

### Example Usage

```bash
export S3KEY
export S3SEC
export S3RGN
virtualmin-install.sh --bundle LAMP --module virtualmin-install-module-s3-scheduled-backups
```
