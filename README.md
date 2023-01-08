# unraid-borg-vm-backup

This script creates archives of a selected vm's to a borg repository. Each archive consist of vm vdisks, configuration and nvram. Main advantage of this script is de-duplication of archives, thanks to BorgBackup program. This script based on JTok script v1.3.1 from https://github.com/JTok/unraid-vmbackup.

## Getting started

To quickly start using this script follow this steps:

1. Install from Community Applications plugin "User Scripts".
2. Install borg utility using this shell script:
```bash
mkdir /boot/bin
wget -O /boot/bin/borg https://github.com/borgbackup/borg/releases/download/1.2.3/borg-linux64
cp /boot/bin/borg /usr/local/bin/
chmod 755 /usr/local/bin/borg
printf "\ncp /boot/bin/* /usr/local/bin\nchmod 755 /usr/local/bin/*" >> /boot/config/go
```
  * Download borg standalone binary from github releases [page](https://github.com/borgbackup/borg/releases). You need binary named `borg-linux64`.
  * Put binary to your boot drive `/boot/bin/` and `/usr/local/bin/`.
  * Make binary executable in `/usr/local/bin/`.
  * Create script to copy binary at server startup from `/boot/bin/` to `/usr/local/bin`.
3. Using shell create your borg repository by executing `borg init -e repokey PATH`, where `PATH` is a path to location where you wanna store backups. It can be local share path or remote server accessible via SSH (borg must be installed on a remote server too).
4. Enter password for borg repository. It can be empty.
5. Go to webGUI Settings -> User Scripts and click "Add new script". Name new script, then edit created script, copy contest of the file "Script" to the text view.
6. Modify following script options:
  * `enabled` set to 1
  * `BORG_REPO` set to repository path specified in step 5.
  * `BORG_PASSPHRASE` set to password specified in step 6.
  * `vms_to_backup` paste vm names that you wanted to backup. Alternatively you can set `backup_all_vms` to 1, to create backups for all vms.
  * `logs_folder` set to folder where you wanna store log files
7. Click "Save changes".
8. Specify schedule for the script.

First vm backup can take some time, depending on: overall vdisks size and sequential read/write speeds of your drives or network speed (in case of remote backup).

To view created archive execute in shell `borg list PATH`. Each vm will have it's own archive. In archive name you can see vm UUID, vm name, state of vm when archive was performed and time of creation separated by `_` underscore.


## Important notes

1. Use dedicated borg repository for backups. This script can delete another archives in existing repository when pruning is enabled.
2. To restore form archive use command `borg extract PATH::ARCHIVE_NAME`. Execute this command from root `/` directory (execute `cd /`) because archive contains absolute file paths. If you execute this command form another working directory, then you will end up with wrong files location and with unnecessary directories being created. Also be aware that this command will overwrite already existing files. So if you do not want to overwrite existing vm vdisks and EFI file, then see documentation for [extract](https://borgbackup.readthedocs.io/en/stable/usage/extract.html) and [mount](https://borgbackup.readthedocs.io/en/stable/usage/mount.html) commands. Also this command will not restore VM configuration. VM configuration will be in root directory `/` with filename same as VM name. Use that file to manually set VM configuration (simply copy-paste to advanced view when create new VM in GUI).

## Features

* De-duplication. Only changed blocks of data will be backed up. That means that backup of untouched VM will occupy almost zero additional space.
* Remote backup. Borg can be used on remote server. Specify ssh path to remote repository in `BORG_REPO` option. See borg documentation for [details](https://borgbackup.readthedocs.io/en/stable/quickstart.html#remote-repositories).
* Full support of pruning logic from Borg. You can flexible adjust pruning parameters to delete unnecessary old VMs. See options `enable_prune`, `keep_within`, `keep_hourly`, `keep_daily`, `keep_weekly`, `keep_monthly`, `keep_yearly`, `keep_last_n`. For details see documentation for [borg prune](https://borgbackup.readthedocs.io/en/stable/usage/prune.html) command.
* Backup on the fly. Ability to backup running VMs using `use_snapshots` option. By default VMs will be shut down before backup.
* Notifications. Script uses unRAID notification system. By default script notifies about important events (such as script starting/ending, VM processing and warnings/error). See options section `logging and notification` in script for fine tune. 

## Configuration

See variables in the script. Each variable has it's own description.

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch.


## Licensing

The code in this project is licensed under GNU GPLv3 license.
