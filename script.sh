#!/bin/bash
#backgroundOnly=true
#arrayStarted=true
#noParity=true

# v0.1.0

# what is the scripts' official name.
official_script_name="script"

# set the name of the script to a variable so it can be used.
me=$(basename "$0")


# this script creates archives to a specified borg repository for vm's vdisks, configurations and nvram's.
# this script based on JTok script v1.3.1 from https://github.com/JTok/unraid-vmbackup.
# this script  licensed under GNU GPLv3 license https://www.gnu.org/licenses/gpl-3.0.en.html 

################################################################
################# user-defined constants start #################
################################################################

# default 0 but set the master switch to 1 if you want to enable the script otherwise it will not run.
enabled="0"

# location of borg repository where archives of vm's will be created. repo must be created before first script launch by using 'borg init' command
export BORG_REPO=""

# default is empty. a pass phrase to access borg repo.
export BORG_PASSPHRASE=""

# default is 0. backup all vms or use vms_to_backup.
# when set to 1, vms_to_backup will be used as an exclusion list.
backup_all_vms="0"

# list of vms that will be backed up separated by a new line.
# if backup_all_vms is set to 1, this will be used as a list of vms to exclude instead.
vms_to_backup="
"

# list of specific vdisks to be skipped separated by a new line. use the full path.
# NOTE: must match path in vm config file. remember this if you change the virtual disk path to enable snapshots.
vdisks_to_skip="
"

# list of specific vdisk extensions to be skipped separated by a new line. this replaces the old ignore_isos variable.
vdisk_extensions_to_skip="
iso
"

# default is 0. use snapshots to backup vms.
# NOTE: vms that are backed up using snapshots will not be shutdown. if a vm is already shutdown the default backup method will be used.
# NOTE: it is highly recommended that you install the qemu guest agent on your vms before using snapshots to ensure the integrity of your backups.
use_snapshots="0"

# default is 0. set this to 1 if you would like to kill a vm if it cant be shutdown cleanly.
kill_vm_if_cant_shutdown="0"

# default is 1. set this to 0 if you do not want a vm to be started if it was running before the backup started. Paused VMs will be left stopped.
set_vm_to_original_state="1"

# default is lz4. compression to use on archive. possible values are described in 'borg help compression' command. lz4 compression is fast and reduce size occupied by sequences of zeros in raw images.
compression="lz4"

# default is 0. set this to 1 if you would like to perform a dry-run archive and see files that will be added to archive for each vm.
archive_dry_run="0"


#### prune parameters ####

# default is 0. 0 means that prune dry run is disabled and prune can be performed as normal. set this to 1 to do a dry-run for prune. this allows monitor pruning logic without actual loosing of archives. this helps in adjusting of pruning parameters assuming that some of them are not clear to understand. if this option set to 1, then it works even if enable_prune option set to 0.
prune_dry_run="0"

# default is 0. 0 means that backups will be creating infinitely. set this to 1 if you want to prune (remove) old backups based on prune parameters listed below. be careful in adjusting pruning parameters and read this description entirely. for example keep_last_n = 1 means that one archive of each vm will be kept. pruning applies to each vm independently based on it's UUID (you can find that value in advanced view of a vm or using 'virsh domuuid VM_NAME' command). For example, you have two vms with different names, different UUID's and option keep_last_n set to 1, then in the repo will be one archive of each vm, 2 in total. if keep_last_n=2, then accordingly there will be two archives of each vm, 4 archives in total. IMPORTANT NOTE: if you create a new vm with the same name, it will be treated as another vm in prune logic. so in case you creating a copy, make sure to copy UUID as well.
enable_prune="1"

# default is empty. specify this value to keep all archives within specified period of time. this is not vm based option, even if its applied to each vm independently. archives affected by this parameter will not be affected by any other prune parameter. value format is "<int><char>", where <char> one of ('H'- hour, 'd' - day, 'w' - week, 'm' - month, 'y' - year). for example value "1w" will keep all archives for 7 last days.
keep_within=""

# all parameters listed below described in detail with 'borg help prune' command. for better understanding of parameters keep_hourly, keep_daily, keep_weekly, keep_monthly and keep_yearly read https://github.com/borgbackup/borg/blob/master/docs/misc/prune-example.txt

# default is empty. number of hourly archives of each vm to keep.
keep_hourly=""

# default is empty. number of daily archives of each vm to keep.
keep_daily=""

# default is empty. number of weekly archives of each vm to keep.
keep_weekly=""

# default is empty. number of monthly archives of each vm to keep.
keep_monthly=""

# default is empty. number of yearly archives of each vm to keep.
keep_yearly=""

# default is empty. number of archives of each vm to keep.
keep_last_n=""

# default is 0. set this to 1 if you want to prune vms archives that is not listed in vms_to_backup option, but stored in repo. options enable_prune or prune_dry_run must be also set to 1. this option is useful in case you backup a vm for a while and decided to stop making backups for that vm by excluding it from vms_to_backup option. then this option will still find that vm in repo (by it's UUID) and prune it eventually (note that enable_prune must be enabled). otherwise you have to manually remove archives for that vm from repo using 'borg delete' command or they will stuck forever.
should_prune_unhandled_vms_archives="0"

# default is 1. set this to 0 if you do not want to receive warnings when unhandled vm archives is found in repo. warning about unhandled vms is useful, because in general you do not expect to have vms in repo that is not listed in vms_to_backup option, unless you exclude a vm from vms_to_backup option. unhandled vm may be an indicator that UUID of a vm has changed unexpectedly to you (for ex. you created copy of a vm with new UUID). note that vm UUID used as id for all vm archives. 
unhandled_vms_archives_warn="1"


#### logging and notifications ####

# default is 1. set to 0 to have log file deleted after the backup has completed.
# NOTE: error logs are separate. settings for error logs can be found in the advanced variables.
keep_log_file="1"

# default is 1. number of successful log files to keep. 0 means infinitely.
number_of_log_files_to_keep="1"

# default is empty. specify location for logs.
logs_folder=""

# default is 0. create a vm specific log in each vm's subfolder using the same retention policy as the vm's backups.
enable_vm_log_file="0"

# default is 1. set to 0 to prevent notification system from being used. Script failures that occur before logging can start, and before this variable is validated will still be sent.
send_notifications="1"

# default is 0. set to 1 to only send error and warning notifications.
only_err_and_warn_notif="0"

# default is 0. set to 1 to receive more detailed notifications. will not work with send_notifications disabled or only_err_and_warn_notif enabled.
detailed_notifications="0"


#### advanced variables ####

# default is snap. extension used when creating snapshots.
# WARNING: do not choose an extension that is the same as one of your vdisks or the script will error out. cannot be blank.
snapshot_extension="snap"

# default is 0. fallback to standard backup if snapshot creation fails.
# NOTE: this will act as though use_snapshots was disabled for just the vm with the failed snapshot command.
snapshot_fallback="0"

# default is 0. pause vms instead of shutting them down during standard backups.
# WARNING: this could result in unusable backups, but I have not thoroughly tested.
pause_vms="0"

# list of vms that will be backed up WITHOUT first shutting down separated by a new line. these must also be listed in vms_to_backup.
# NOTE: vms backed up via snapshot will not be shutdown (see use_snapshots option).
# WARNING: using this setting can result in an unusable backup. not recommended.
vms_to_backup_running="
"

# default is 0. set to 1 to have reconstruct write (a.k.a. turbo write) enabled during the backup and then disabled after the backup completes.
# NOTE: may break auto functionality when it is implemented. do not use if reconstruct write is already enabled. backups may run faster with this enabled.
enable_reconstruct_write="0"

# default is 1. set to 0 if you would like to skip backing up xml configuration files.
backup_xml="1"

# default is 1. set to 0 if you would like to skip backing up nvram files.
backup_nvram="1"

# default is 1. set to 0 if you would like to skip backing up vdisks. setting this to 0 will automatically disable compression.
backup_vdisks="1"

# default is 0. set this to 1 if you would like to start a vm after it has successfully been backed up. will override set_vm_to_original_state when set to 1.
start_vm_after_backup="0"

# default is 0. set this to 1 if you would like to start a vm after it has failed to have been backed up. will override set_vm_to_original_state when set to 1.
start_vm_after_failure="0"

# default is 20. set this to the number of times you would like to check if a clean shutdown of a vm has been successful.
clean_shutdown_checks="20"

# default is 30. set this to the number of seconds to wait in between checks to see if a clean shutdown has been successful.
seconds_to_wait="30"

# default is 1. set to 0 to have error log files deleted after the backup has completed.
keep_error_log_file="1"

# default is 10. number of error log files to keep. 0 means infinitely.
number_of_error_log_files_to_keep="10"

##############################################################
################# user-defined constants end #################
##############################################################


######################################################################
################# DO NOT EDIT SCRIPT BELOW THAT LINE #################
######################################################################


#########################################################
################# global variables start #################
#########################################################

######### variables in this section can be used in any part of script #########

# create timestamp variable for rolling backups.
timestamp="$(date '+%Y%m%d_%H%M')""_"

# initialize error variable. assume no errors.
errors="0"

# init vm variable. this variable contains name of current vm in backup process.
vm=""

# variable that contains uuid of current $vm
vm_uuid=""

# array that contains uuid's of all vm from vms_to_backup option. populated during backup process of each vm
vms_uuid=()

# init array of current $vm vdisks.
vdisks_path=()

# dictionary of current $vm vdisks specifications from xml configuration file. key is vdisk path from $vdisks_path, value is vdisk specification.
declare -A vdisks_specs

# variable to store current state of current $vm
vm_state=""

# variable to store state of current $vm before backup process
vm_original_state=""

# vm state to which vm must be transitioned to make traditional backup. by default is 'shut off' if pause_vms is 1, then value will be 'paused'
vm_desired_state="shut off"


#######################################################
################# global variables end #################
#######################################################


################################################
################# script start #################
################################################

#### define functions start ####

  # pass log messages to log files and system notifications.
  log_message () {

    # assign arguments to local variables for readability.
    local message="$1"
    local description="$2"

    # set importance from $3 or default when $3 unset
    local importance=${3:-"information"}
    local force_notification="$4"

    # add importance to message
    message="$importance: $message"
    
    

    # add the message to the main log file.
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee -a "$logs_folder$timestamp""unraid-vmbackup.log"

    # add the message to the vm specific log file if enabled.
    if [[ -n "$vm_log_file" ]] && [ "$enable_vm_log_file" -eq 1 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$vm_log_file"
    fi

    if [[ "$importance" == "alert" ]]; then
      errors="1"
    fi

    # send notification if needed
    if [ "$send_notifications" -eq 1 ] && [[ "$importance" == "warning" || "$importance" == "alert" || "$detailed_notifications" -eq 1 || "$force_notification" == "force_notification" ]]; then
      /usr/local/emhttp/plugins/dynamix/scripts/notify -s "unRAID Borg VM Backup" -d "$description" -i "$importance" -m "$(date '+%Y-%m-%d %H:%M:%S') $message"
      # high notification rate causes some notifications not to be sent. sleep helps reduce possible high rate
      sleep 0.2
    fi
  }

  # pass notification messages to system notifications.
  notification_message () {

    # assign arguments to local variables for readability.
    local message="$1"
    local description="$2"
    local importance=${3:-"information"}

    # add importance to message
    message="$importance: $message"

    # show the message in the log.
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message"

    # send message notification.
    if [[ -n "$description" ]] && [[ -n "$importance" ]]; then
      
      if [[ "$importance" != "warning" && "$importance" != "alert" && "$only_err_and_warn_notif" -eq 1 ]]; then
        return
      fi

      /usr/local/emhttp/plugins/dynamix/scripts/notify -s "unRAID Borg VM Backup" -d "$description" -i "$importance" -m "$(date '+%Y-%m-%d %H:%M:%S') $message"
      # high notification rate causes some notifications not to be sent. sleep helps reduce possible high rate
      sleep 0.2
    fi
  }

  # functions that retrieving vm disks locations from xml config file.
  # variables affected by calling this func is vdisks_path and vdisks_specs
  get_vm_vdisks () {
    # get number of vdisks associated with the vm.
    local vdisk_count=$(xmllint --xpath "count(/domain/devices/disk/source/@file)" "$vm.xml")

    # unset and init array for vdisks paths.
    unset vdisks_path
    vdisks_path=()

    # unset and init dictionary for vdisk_specs.
    unset vdisks_specs
    declare -g -A vdisks_specs

    # get vdisk paths from config file.
    for (( i=1; i<=vdisk_count; i++ )); do
      
      local vdisk_path="$(xmllint --xpath "string(/domain/devices/disk[$i]/source/@file)" "$vm.xml")"
      local vdisk_spec="$(xmllint --xpath "string(/domain/devices/disk[$i]/target/@dev)" "$vm.xml")"

      vdisks_path+=("$vdisk_path")
      vdisks_specs["$vdisk_path"]="$vdisk_spec"
    
    done

    # get vdisk names to check on current backups
    for i in "${!vdisks_path[@]}"
    do

      local disk="${vdisks_path[i]}"
      
      # if disk path empty then contionue loop
      if [[ -z "$disk" ]]; then
        continue
      fi

      # assume disk will not be skipped.
      local skip_disk="0"

      if [[ ! -e "$disk" ]]; then
        
        log_message "disk from xml config at $disk does not exsist. skipping disk."
        skip_disk="1"
      
      fi

      if [[ "$skip_disk" -eq 0 ]]; then
        # check to see if vdisk should be explicitly skipped.
        for skipvdisk_name in $vdisks_to_skip
        do

          if [ "$skipvdisk_name" == "$disk" ]; then
            skip_disk="1"
            log_message "$disk on $vm was found in vdisks_to_skip. skipping disk."
          fi
        
        done
      fi

      # get the extension of the disk.
      local disk_extension="${disk##*.}"

      # disable case matching.
      shopt -s nocasematch

      # check to see if vdisk extension is the same as the snapshot extension. if it is, error and skip the vm.
      if [[ "$disk_extension" == "$snapshot_extension" ]]; then
        log_message "extension for $disk on $vm is the same as the snapshot extension $snapshot_extension. disk will always be skipped. this usually means that the disk path in the config was not changed from /mnt/user. if disk path is correct, then try changing snapshot_extension or vdisk extension." "cannot backup vdisk on $vm" "alert"
      fi

      if [[ "$skip_disk" -eq 0 ]]; then
        # check to see if vdisk should be skipped by extension.
        for skipvdisk_extension in $vdisk_extensions_to_skip
        do

          if [[ "$skipvdisk_extension" == "$disk_extension" ]]; then
            
            skip_disk="1"
            log_message "extension for $disk on $vm was found in vdisks_extensions_to_skip. skipping disk."
          
          fi
        
        done
      fi

      if [[ "$skip_disk" == "1" ]]; then

        # exclude disk form being archived
        unset 'vdisks_path[i]'
        unset 'vdisks_specs[$disk]'

      fi

      # re-enable case matching.
      shopt -u nocasematch
    
    done
  }

  # lock vm disks by changing permissions to read-only so disks can't be modified during archive process. only works if $vm in 'shut off' state.
  lock_vm_disks() {
    log_message "vm_state is $vm_state. locking disk images of $vm to prevent them from modification during archive process. if script fails on this vm then check disk images file permissions and recover them to rwxrwxrwx mode as needed."

    for disk in "${vdisks_path[@]}"; do
      chmod 444 "$disk"
    done
  }

  # unlock vm disks by recovering original permissions to full access.
  unlock_vm_disks() {
    log_message "unlocking disk images of $vm."

    for disk in "${vdisks_path[@]}"; do
      chmod 777 "$disk"
    done
  }

  # take vm snapshot to perform backup of running vm
  # return codes:
  # 0 - successfully took vm snapshot of all vdisks
  # <1-127> - number of failed disk snapshots
  take_vm_snapshot () {
    local rc=0

    for i in "${!vdisks_path[@]}"; do
      
      local disk="${vdisks_path[i]}"

      # set variable for qemu agent is installed.
      local qemu_agent_installed=$(virsh qemu-agent-command "$vm" '{"execute":"guest-info"}' | grep -c "version" | awk '{ print $0 }')

      local disk_filename=$(basename "$disk")
      local disk_directory=$(dirname "$disk")
      # remove trailing slash.
      disk_directory=${disk_directory%/}
      
      # get name of current disk without extension and add snapshot extension.
      local snap_name="${disk_filename%.*}.$snapshot_extension"

      log_message "able to perform snapshot for disk $disk on $vm. use_snapshots is $use_snapshots. vm_state is $vm_state."

      # create snapshot command.
      # unset array for snapshot_cmd.
      unset snapshot_cmd
      # initialize snapshot_cmd as empty array.
      local snapshot_cmd=()

      # find each vdisk_spec and use it to build a snapshot command.
      for vdisk_spec in "${vdisks_specs[@]}"; do

        # check to see if snapshot command is empty.
        if [ ${#snapshot_cmd[@]} -eq 0 ]; then

          # build initial snapshot command.
          snapshot_cmd=(virsh)
          snapshot_cmd+=(snapshot-create-as)
          snapshot_cmd+=(--domain "$vm")
          snapshot_cmd+=(--name "$vm-$snap_name")

          # check to see if this is the vdisk we are currently working with.
          if [ "$vdisk_spec" == "${vdisks_specs[$disk]}" ]; then

            # if it is, set the command to make a snapshot.
            snapshot_cmd+=(--diskspec "$vdisk_spec,file=$disk_directory/$snap_name,snapshot=external")
          else

            # if it is not, set the command to not make a snapshot.
            snapshot_cmd+=(--diskspec "$vdisk_spec,snapshot=no")
          fi

        else

          # add additional extensions to snapshot command.
          # check to see if this is the vdisk we are currently working with.
          if [ "$vdisk_spec" == "${vdisks_specs[$disk]}" ]; then
            
            # if it is, set the command to make a snapshot.
            snapshot_cmd+=(--diskspec "$vdisk_spec,file=$disk_directory/$snap_name,snapshot=external")
          else
            
            # if it is not, set the command to not make a snapshot.
            snapshot_cmd+=(--diskspec "$vdisk_spec,snapshot=no")
          fi
        
        fi
      done

      # add additional options to snapshot command.
      snapshot_cmd+=(--disk-only)
      snapshot_cmd+=(--no-metadata)
      snapshot_cmd+=(--atomic)

      # check to see if qemu agent is installed for snapshot creation command.
      if [[ "$qemu_agent_installed" -eq 1 ]]; then

        # set quiesce
        snapshot_cmd+=(--quiesce)
        log_message "qemu agent found. enabling quiesce on snapshot."

      else
        log_message "qemu agent not found. disabling quiesce on snapshot."
      fi

      local snapshot_res
      local snapshot_rc

      snapshot_res=$( "${snapshot_cmd[@]}" 2>&1 )
      snapshot_rc=$?

      # create snapshot.
      if [[ $snapshot_rc -ne 0 ]]; then
        
        log_message "snapshot command failed on $snap_name for $vm." "$vm snapshot failed" "alert"
        log_message "snapshot command was '${snapshot_cmd[*]}'. command output is:"$'\n'"$snapshot_res"

        rc+=1

      else
        log_message "snapshot command succeeded on $snap_name for $vm."
      fi
    
    done

    return $rc
  }

  # committing disks snapshot for vm. it is safe to call this func even if no snapshots exists for vm or for some if it's disks.
  # variables affected by calling this func is vm_state
  commit_vm_snapshot() {
    for i in "${!vdisks_path[@]}"; do
      local disk="${vdisks_path[i]}"
      
      # get directory of current disk.
      local disk_directory=$(dirname "$disk")
      # remove trailing slash.
      disk_directory=${disk_directory%/}

      # get disk filename
      local disk_filename=$(basename "$disk")

      # get name of current disk without extension and add snapshot extension.
      local snap_name="${disk_filename%.*}.$snapshot_extension"

      # check to see if snapshot was created.
      if [[ -f "$disk_directory/$snap_name" ]]; then

        vm_state=$(virsh domstate "$vm")

        # verify vm is still running before attempting to commit changes from snapshot.
        if [ "$vm_state" == "running" ]; then

          # commit changes from snapshot.
          virsh blockcommit "$vm" "${vdisks_specs[$disk]}" --active --wait --verbose --pivot
          
          # wait 5 seconds.
          sleep 5
          log_message "committed changes from snapshot for $disk on $vm."

          # see if snapshot still exists.
          if [[ -f "$disk_directory/$snap_name" ]]; then

            # if it does, forcibly remove it.
            rm -fv "$disk_directory/$snap_name"
            log_message "forcibly removed snapshot $disk_directory/$snap_name for $vm."
          
          fi

        else

          log_message "snapshot performed for $vm, but vm state is $vm_state. cannot commit changes from snapshot at path $disk_directory/$snap_name." "script skipping snapshot commit. manual commit required for VM $vm" "warning"
          log_message "information: for manual commit execute command \`virsh blockcommit \"$vm\" \"${vdisks_specs[$disk]}\" --active --wait --verbose --pivot\`"
        
        fi
      fi
    done
  }

  # perform snapshot fallback. if $vm listed in $vms_to_backup_running then no actions will be made, otherwise vm will be transitioned to $vm_desired_state.
  # global variables affected by this func is vm_state and vm_original_state
  # return codes:
  # 0 - successfully performed fallback
  # 1 - failed to perform fallback
  perform_snapshot_fallback() {
    local rc=0
    
    # get the state of the vm for making sure it is off before backing up.
    vm_state=$(virsh domstate "$vm")

    # get the state of the vm for putting the VM in it's original state after backing up.
    vm_original_state="$vm_state"

    # prepare vm for backup.
    if prepare_vm "$vm" "$vm_state"; then 
      
      # created snapshots can be committed to backup full disk images
      commit_vm_snapshot

    else 
      rc=1
    fi

    return $rc
  }

  # function that performs creating a vm archive. vm data retrieved from global variables. function has only one input parameter:
  # $@ - array of files paths that have to be included in archive
  perform_archive () {
    local paths=( "$@" )

    # build archive name. 
    # $vm_uuid in front used as prefix for correct pruning of vm archives
    # getting new timestamp instead of using value from $timestamp variable stand for more accurate archive creation time. also prune logic not based on using same timestamp in archives names as it is in logs clearing logic.
    local archive_name="$vm_uuid-$vm-$vm_state-$(date --iso-8601='seconds')"
    
    # replace all space characters with underscores
    archive_name=${archive_name// /_}
    
    local archive_cmd=(borg)
    archive_cmd+=(create)
    archive_cmd+=(--compression "$compression")

    if [[ "$archive_dry_run" -eq 1 ]]; then
      archive_cmd+=(--dry-run --list)
    fi

    archive_cmd+=("::$archive_name")
    archive_cmd+=( "${paths[@]}" )

    log_message "begin archive process for $vm. it might take some time to finish."

    local archive_res
    local archive_rc
    
    archive_res=$( "${archive_cmd[@]}" 2>&1 )
    archive_rc="$?"

    if [[ $archive_rc -eq 0 ]]; then
      # send a message to the user based on whether there was an actual copy or a dry-run.
      if [ $archive_dry_run -eq 1 ]; then
        
        log_message "dry-run backup of $vm to archive named $archive_name completed."
        log_message "dry-run archive result:"$'\n'"$archive_res"
      
      else
        log_message "backup of $vm to archive named $archive_name complete."
      fi
    
    else
      
      log_message "archive command finished with error. see logs for details." "archive command failed" "alert"
      log_message "archive command finished with error. command was '${archive_cmd[*]}'. command result:"$'\n'"$archive_res" "archive command failed"
    
    fi
  }

  # perform prune command for current $vm based on prune parameters
  #   vm - name of vm for which perform prune. required
  #   vm_uuid - uuid of vm for which perform prune. required
  prune_vm_archives () {
    local vm="$1"
    local vm_uuid="$2"
    local prune_cmd=(borg prune --verbose --prefix "$vm_uuid")
    local rc=0

    log_message "starting vm archives pruning procedure"

    if [[ $prune_dry_run -eq 1 ]]; then
      prune_cmd+=(--dry-run --list --verbose)
    fi

    if [[ -n "$keep_within" ]]; then
      prune_cmd+=("--keep-within=$keep_within")
    fi

    if [[ -n "$keep_hourly" ]]; then
      prune_cmd+=("--keep-hourly=$keep_hourly")
    fi

    if [[ -n "$keep_daily" ]]; then
      prune_cmd+=("--keep-daily=$keep_daily")
    fi
    
    if [[ -n "$keep_weekly" ]]; then
      prune_cmd+=("--keep-weekly=$keep_weekly")
    fi
    
    if [[ -n "$keep_monthly" ]]; then
      prune_cmd+=("--keep-monthly=$keep_monthly")
    fi
    
    if [[ -n "$keep_yearly" ]]; then
      prune_cmd+=("--keep-yearly=$keep_yearly")
    fi
    
    if [[ -n "$keep_last_n" ]]; then
      prune_cmd+=("--keep-last=$keep_last_n")
    fi
    
    local prune_res
    local prune_rc

    prune_res=$( "${prune_cmd[@]}" 2>&1 )
    prune_rc="$?"

    if [[ $prune_rc -eq 0 ]]; then
      
      if [[ $prune_dry_run -eq 0 ]]; then
        log_message "successfully pruned archives for $vm"
      else
        log_message "successfully perform dry run prune for $vm. result:"$'\n'"$prune_res"
      fi
    
    else
      
      rc=1
      log_message "prune for $vm completed with code $prune_rc. command was '${prune_cmd[*]}'. command result:"$'\n'"$prune_res" "archive command failed" "alert"
    
    fi

    return $rc
  }

  # function to prune archives of vms that is not listed in vms_to_backup option
  # return codes:
  # 0 - successfully pruned unhandled vm archives
  # 1 - failed to prune archives for one unhandled vm
  prune_unhandled_vms_archives () {
    # cmd which outputs archive names in the repo divided by a newline
    local list_archives_cmd=(borg list "--format=\"{archive}{NL}\"")
    declare -A archives_uuid_to_prune
    local list_cmd_res
    local rc=0

    list_cmd_res=$( "${list_archives_cmd[@]}" )

    if [[ $? -ne 0 ]]; then

      log_message "failed to get list of archives from repository. return code is $?. message is:"$'\n'"$list_cmd_res" "failed to list archives from repo" "warning"
      return 1

    fi

    # loop through archive names, find vms that haven't been handled by this script execution and mark them for pruning
    for archive_name in $list_cmd_res; do
      
      # regex to match an uuid in begining of an archive name
      local prefix_uuid_patt='^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?'

      # check that archive name starts with uuid
      if [[ ! "$archive_name" =~ $prefix_uuid_patt ]]; then
        continue
      fi

      # select uuid part from archive_name
      local archive_uuid=${archive_name::36}
      local vm_uuid=""
      local shoud_perform_prune="1"

      for vm_uuid in "${vms_uuid[@]}"; do
        # if uuid from repo presented in vm uuid's that's already have been processed, then skip prune for that uuid
        if [[ $vm_uuid -eq $archive_uuid ]]; then
          shoud_perform_prune="0"
        fi

      done

      if [[ $shoud_perform_prune -eq 1 ]]; then
        # get vm name from archive name with pattern <vm_uuid>-<vm_name>-<vm_state>-<iso8601datetime> 

        # get len of name + state part. subtract len of uuid (36) + "-" (1) + "-" (1) + len of ISO-8601 datetime format with timezone (25) from archive_name
        local name_state_len=$( ${#archive_name}-36-1-1-25 )
        # select pair of name + state from archive_name
        local name_state=${archive_name:37:name_state_len}
        # select vm name part.
        local vm_name=${name_state%-*}

        archives_uuid_to_prune["$archive_uuid"]=$vm_name
      
      fi
    
    done

    if [[ ${#archives_uuid_to_prune[@]} -ge 1 ]]; then
      
      if [[ $unhandled_vms_archives_warn -eq 1 ]]; then
        log_message "unhandled vms archives found in repo." "unhandled archives found" "warning"
      else
        log_message "unhandled vms archives found in repo."
      fi

    else

      log_message "unhandled vms archives not found in repo. no additional prune will be made."
      return 0

    fi

    if [[ "$should_prune_unhandled_vms_archives" -eq 0 ]]; then
      
      log_message "should_prune_unhandled_vms_archives is $should_prune_unhandled_vms_archives. no additional prune will be made."
      return 0
    
    else 
      log_message "should_prune_unhandled_vms_archives is $should_prune_unhandled_vms_archives. begin prune procedure."
    fi

    for uuid in "${!archives_uuid_to_prune[@]}"; do
      
      local vm_name=${archives_uuid_to_prune[$uuid]}
      local prune_rc
      
      prune_vm_archives "$vm_name" "$uuid"
      prune_rc=$?

      if [[ "$prune_rc" -ne 0 ]]; then
        rc=1
      fi
    done

    return $rc
  }

  # prepare vm for backup by trying to put it in a desired state (shouted off or paused). global variable vm_state is affected by calling this func.
  # return codes:
  # 0 - vm successfully transitioned to desired state
  # 1 - failed to transition vm to desired state
  prepare_vm () {
    # return code
    local rc=0

    # check to see if the vm is in the desired state.
    if [ "$vm_state" == "$vm_desired_state" ]; then
      rc=0

    # check to see if vm is shut off.
    elif [ "$vm_state" == "shut off" ] && [ ! "$vm_desired_state" == "shut off" ]; then
      rc=0

    # if the vm is running, try to get it to the desired state.
    elif [ "$vm_state" == "running" ] || { [ "$vm_state" == "paused" ] && [ ! "$vm_desired_state" == "paused" ]; }; then

      # the shutdown of the vm may last a while so we are going to check periodically based on global input variables.
      for (( i=1; i<=clean_shutdown_checks; i++ )); do
        
        log_message "cycle $i of $clean_shutdown_checks: waiting $seconds_to_wait seconds before checking if the vm has entered the desired state."

        if [ "$vm_desired_state" == "paused" ]; then
          
          # attempt to pause the vm.
          virsh suspend "$vm"
          log_message "$vm is $vm_state. vm desired state is $vm_desired_state. performing $clean_shutdown_checks $seconds_to_wait second cycles waiting for $vm to pause."

        elif [ "$vm_desired_state" == "shut off" ]; then

          # resume the vm if it is suspended, based on testing this should be instant but will trap later if it has not resumed.
          if [ "$vm_state" == "paused" ]; then
            
            log_message "action: $vm is $vm_state. vm desired state is $vm_desired_state. resuming."

            # resume the vm.
            virsh resume "$vm"
          
          fi

          # attempt to cleanly shutdown the vm.
          virsh shutdown "$vm"
          log_message "performing $clean_shutdown_checks $seconds_to_wait second cycles waiting for $vm to shutdown cleanly."
        
        fi

        # wait x seconds based on how many seconds the user wants to wait between checks for a clean shutdown.
        sleep $seconds_to_wait

        # get the state of the vm.
        vm_state=$(virsh domstate "$vm")

        # if the vm is running decide what to do.
        if [ ! "$vm_state" == "$vm_desired_state" ]; then

          # if we have already exhausted our wait time set by the script variables then its time to do something else.
          if [ $i = "$clean_shutdown_checks" ] ; then

            # check if the user wants to kill the vm on failure of unclean shutdown.
            if [ "$kill_vm_if_cant_shutdown" -eq 1 ]; then
              
              log_message "kill_vm_if_cant_shutdown is $kill_vm_if_cant_shutdown. killing vm."

              # destroy vm, based on testing this should be instant and without failure.
              virsh destroy "$vm"

              # get the state of the vm.
              vm_state=$(virsh domstate "$vm")

              # if the vm is shut off then proceed or give up.
              if [ "$vm_state" == "shut off" ]; then

                rc=0
                break

              else
                rc=1
              fi

            # if the user doesn't want to force a shutdown then there is nothing more to do so i cannot backup the vm.
            else
              rc=1
            fi

          fi

        # if the vm is shut off then go onto backing it up.
        elif [ "$vm_state" == "$vm_desired_state" ]; then
          
          rc=0
          break

        # if the vm is in a state that is not explicitly defined then do nothing as it is unknown how to handle it.
        else
          rc=1
        fi
     
      done

    # if the vm is suspended then something went wrong with the attempt to recover it earlier so do not attempt to backup.
    elif [ "$vm_state" == "suspended" ]; then
      rc=1

    # if the vm is in a state that has not been explicitly defined then do nothing as it is unknown how to handle it.
    else
      rc=1
    fi

    if [[ "$rc" -eq 0 ]]; then
      log_message "$vm is $vm_state. vm desired state is $vm_desired_state. successfully prepared vm for backup."
    else
      log_message "$vm is $vm_state. vm desired state is $vm_desired_state. failed to prepare vm for backup" "$vm shutdown failed" "alert"
    fi

    return $rc
  }

#### define functions end ####


#### validate user variables start ####

  # check the name of the script is as it should be. if yes, continue. if no, exit.
  if [ "$me" == "$official_script_name" ]; then
    notification_message "official_script_name is $official_script_name. script file's name is $me. script name is valid. continuing."
  elif [ ! "$me" == "$official_script_name" ]; then

    notification_message "official_script_name is $official_script_name. script file's name is $me. script name is invalid. exiting." "invalid script name" "alert"
    exit 1

  fi


  # check to see if the script has been enabled or disabled by the user. if yes, continue if no, exit. if input invalid, exit.
  if [[ "$enabled" =~ ^(0|1)$ ]]; then

    if [ "$enabled" -eq 1 ]; then
      notification_message "enabled is $enabled. script is enabled. continuing."
    elif [ ! "$enabled" -eq 1 ]; then

      notification_message "enabled is $enabled. script is disabled. exiting." "script is disabled" "alert"
      exit 1

    fi

  else

    notification_message "enabled is $enabled. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'enabled'" "alert"
    exit 1

  fi

  borg info
  check_borg_repo_rc=$?

  # check to see if the BORG_REPO specified by the user available. if yes, continue if no, exit.
  if [[ check_borg_repo_rc -eq 0 ]]; then
    notification_message "BORG_REPO is $BORG_REPO. this repository exists and available. continuing."
  else

    notification_message "BORG_REPO is $BORG_REPO. failed to check repository availability. check correctness of options BORG_REPO and BORG_PASSPHRASE and repository availability. exiting." "repo is unavailable" "alert"
    exit 1

  fi

  if [[ -z "$logs_folder" ]]; then

    notification_message "logs_folder is empty. logs_folder must be specified to perform logs. exiting." "option 'logs_folder' is empty" "alert"
    exit 1

  fi

  # check log folder for trailing slash. add if missing.
  last_char=${logs_folder:(-1)}
  [[ ! $last_char == "/" ]] && logs_folder="$logs_folder/"; :


  # create the log file subfolder for storing log files.
  if [ ! -d "$logs_folder" ] ; then

    notification_message "$logs_folder does not exist. creating it."

    # make the directory as it doesn't exist. added -v option to give a confirmation message to command line.
    mkdir -vp "$logs_folder"

  else
    notification_message "$logs_folder exists. continuing."
  fi


  # check to see if the logs_folder specified by the user exists. if yes, continue if no, exit. if exists check if writable, if yes continue, if not exit. if input invalid, exit.
  if [[ -d "$logs_folder" ]]; then

    notification_message "logs_folder is $logs_folder. this location exists. continuing."

    # if logs_folder does exist check to see if the logs_folder is writable.
    if [[ -w "$logs_folder" ]]; then
      notification_message "logs_folder is $logs_folder. this location is writable. continuing."
    else

      notification_message "logs_folder is $logs_folder. this location is not writable. exiting." "logs_folder is not writable" "alert"
      exit 1

    fi

  else

    notification_message "logs_folder is $logs_folder. this location does not exist. exiting." "logs_folder directory doesn't exists" "alert"
    exit 1

  fi

  ### Logging Started ###
  log_message "Start logging to log file."


  #### logging and notifications ####

  # check to see if notifications should be sent. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$send_notifications" =~ ^(0|1)$ ]]; then

    if [ "$send_notifications" -eq 0 ]; then
      log_message "send_notifications is $send_notifications. notifications will not be sent."
    elif  [ "$send_notifications" -eq 1 ]; then
      log_message "send_notifications is $send_notifications. notifications will be sent."
    fi

  else

    log_message "send_notifications is $send_notifications. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'send_notifications'" "alert"
    exit 1

  fi

  # check to see if notifications should be sent. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$detailed_notifications" =~ ^(0|1)$ ]]; then

    if [ "$detailed_notifications" -eq 0 ]; then
      log_message "detailed_notifications is $detailed_notifications. detailed notifications will not be sent."
    elif  [ "$detailed_notifications" -eq 1 ]; then
      log_message "detailed_notifications is $detailed_notifications. detailed notifications will be sent."
    fi

  else

    log_message "detailed_notifications is $detailed_notifications. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'detailed_notifications'" "alert"
    exit 1

  fi

  # check to see if only error notifications should be sent. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$only_err_and_warn_notif" =~ ^(0|1)$ ]]; then

    if [ "$only_err_and_warn_notif" -eq 0 ]; then
      log_message "only_err_and_warn_notif is $only_err_and_warn_notif. normal notifications will be sent if send_notifications is enabled."
    elif  [ "$only_err_and_warn_notif" -eq 1 ]; then
      log_message "only_err_and_warn_notif is $only_err_and_warn_notif. only error notifications will be sent if send_notifications is enabled."
    fi

  else

    log_message "only_err_and_warn_notif is $only_err_and_warn_notif. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'only_err_and_warn_notif'" "alert"
    exit 1

  fi

  # notify user that script has started.
  if [ "$send_notifications" -eq 1 ] && [ "$only_err_and_warn_notif" -eq 0 ]; then
    notification_message "unRAID Borg VM Backup is starting. Look for finished message." "script starting" "normal"
  fi

  # check to see if log files should be kept. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$keep_log_file" =~ ^(0|1)$ ]]; then

    if [ "$keep_log_file" -eq 0 ]; then
      log_message "keep_log_file is $keep_log_file. log files will not be kept."
    elif  [ "$keep_log_file" -eq 1 ]; then
      log_message "keep_log_file is $keep_log_file. log files will be kept."
    fi

  else

    log_message "keep_log_file is $keep_log_file. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'keep_log_file'" "alert"
    exit 1

  fi


  # check to see how many log files should be kept. if yes, continue if no, continue if input invalid, exit.
  if [[ "$number_of_log_files_to_keep" =~ ^[0-9]+$ ]]; then

    if [ "$number_of_log_files_to_keep" -eq 0 ]; then
      log_message "number_of_log_files_to_keep is $number_of_log_files_to_keep. an infinite number of log files will be kept. be sure to pay attention to how many log files there are."
    elif [ "$number_of_log_files_to_keep" -gt 40 ]; then
      log_message "number_of_log_files_to_keep is $number_of_log_files_to_keep. this is a lot of log files to keep."
    elif [ "$number_of_log_files_to_keep" -ge 1 ] && [ "$number_of_log_files_to_keep" -le 40 ]; then
      log_message "number_of_log_files_to_keep is $number_of_log_files_to_keep. this is probably a sufficient number of log files to keep."
    fi

  else

    log_message "number_of_log_files_to_keep is $number_of_log_files_to_keep. this is not a valid format. expecting a number between [0 - 1000000]. exiting." "invalid format for option 'number_of_log_files_to_keep'" "alert"
    exit 1

  fi

  # check to see if vm specific log files are enabled. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$enable_vm_log_file" =~ ^(0|1)$ ]]; then

    if [ "$enable_vm_log_file" -eq 0 ]; then
      log_message "enable_vm_log_file is $enable_vm_log_file. vm specific logs will not be created."
    elif  [ "$enable_vm_log_file" -eq 1 ]; then
      log_message "enable_vm_log_file is $enable_vm_log_file. vm specific logs will be created."
    fi

  else

    log_message "enable_vm_log_file is $enable_vm_log_file. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'enable_vm_log_file'" "alert"
    exit 1

  fi

  # check to see if all vms should be backed up. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$backup_all_vms" =~ ^(0|1)$ ]]; then

    if [ "$backup_all_vms" -eq 0 ]; then
      log_message "backup_all_vms is $backup_all_vms. only vms listed in vms_to_backup will be backed up."
    elif [ "$backup_all_vms" -eq 1 ]; then
      log_message "backup_all_vms is $backup_all_vms. vms_to_backup will be ignored. all vms will be backed up."
    fi

  else

    log_message "backup_all_vms is $backup_all_vms. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'backup_all_vms'" "alert"
    exit 1

  fi

  # check to see if snapshots should be used. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$use_snapshots" =~ ^(0|1)$ ]]; then

    if [ "$use_snapshots" -eq 0 ]; then
      log_message "use_snapshots is $use_snapshots. vms will not be backed up using snapshots."
    elif [ "$use_snapshots" -eq 1 ]; then
      log_message "use_snapshots is $use_snapshots. vms will be backed up using snapshots if possible."
    fi

  else

    log_message "use_snapshots is $use_snapshots. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'use_snapshots'" "alert"
    exit 1

  fi

  # check to see if vm should be killed if clean shutdown fails. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$kill_vm_if_cant_shutdown" =~ ^(0|1)$ ]]; then

    if [ "$kill_vm_if_cant_shutdown" -eq 0 ]; then
      log_message "kill_vm_if_cant_shutdown is $kill_vm_if_cant_shutdown. vms will not be forced to shutdown if a clean shutdown can not be detected."
    elif [ "$kill_vm_if_cant_shutdown" -eq 1 ]; then
      log_message "kill_vm_if_cant_shutdown is $kill_vm_if_cant_shutdown. vms will be forced to shutdown if a clean shutdown can not be detected."
    fi

  else

    log_message "kill_vm_if_cant_shutdown is $kill_vm_if_cant_shutdown. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'kill_vm_if_cant_shutdown'" "alert"
    exit 1

  fi


  # check to see if vm should be set to original state after backup. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$set_vm_to_original_state" =~ ^(0|1)$ ]]; then

    if [ "$set_vm_to_original_state" -eq 0 ]; then
      log_message "set_vm_to_original_state is $set_vm_to_original_state. vms will not be set to their original state after backup."
    elif [ "$set_vm_to_original_state" -eq 1 ]; then
      log_message "set_vm_to_original_state is $set_vm_to_original_state. vms will be set to their original state after backup."
    fi

  else

    log_message "set_vm_to_original_state is $set_vm_to_original_state. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'set_vm_to_original_state'" "alert"
    exit 1

  fi

  
  # patterns used to match compression methods syntaxes as described in 'borg help compression'
  # apostrophe (') quotation in pattern used for word boundary support in regex (\< and \> string anchors) as discussed in https://stackoverflow.com/questions/9792702/does-bash-support-word-boundary-regular-expressions
  lz4_patt='^(auto,)?lz4$'
  zstd_patt='^(auto,)?zstd(,\<([1-9]|1[0-9]|2[0-2])\>)?$'
  zlib_lzma_patt='^(auto,)?(zlib|lzma)(,[0-9])?$'

  # check compression method to be used
  if [[ -z "$compression" ]]; then
    log_message "compression is empty. will be used default compression lz4."
    compression="lz4"
  elif [[ "$compression" == "none" ]]; then
    log_message "compression is $compression. compression will not be used."
  elif [[ "$compression" =~ $lz4_patt || "$compression" =~ $zstd_patt || "$compression" =~ $zlib_lzma_patt || "$compression" == "auto" ]]; then
    log_message "information: compression is $compression. this type of compression will be used."
  else

    log_message "compression is $compression. expecting one of: empty string (\"\") or \"none\" or \"[auto,]lz4\" or \"[auto,]zstd[,(1-22)]\" or \"[auto,]zlib[,(0-9)]\" or \"[auto,]lzma[,(0-9)]\". exiting." "invalid format for option 'compression'" "alert"
    exit 1

  fi

  if [[ "$archive_dry_run" =~ ^(0|1)$ ]]; then 
    
    if [[ "$archive_dry_run" -eq 1 ]]; then
      log_message "archive_dry_run is $archive_dry_run. no vms will be actually backuped. check logs to see calculated backup result." "archive_dry_run is ON" "warning"
    else
      log_message "archive_dry_run is $archive_dry_run. archives with vms will be created."
    fi

  else

    log_message "archive_dry_run is $archive_dry_run. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'archive_dry_run'" "alert"
    exit 1

  fi

  if [[ "$enable_prune" =~ ^(0|1)$ ]]; then 

    if [[ "$enable_prune" -eq 1 ]]; then
      log_message "enable_prune is $enable_prune. archives pruning will be used."
    else
      log_message "enable_prune is $enable_prune. no archive will be pruned."
    fi

  else

    log_message "enable_prune is $enable_prune. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'enable_prune'" "alert"
    exit 1

  fi

  if [[ "$prune_dry_run" =~ ^(0|1)$ ]]; then 

    if [[ "$prune_dry_run" -eq 1 ]]; then
      log_message "prune_dry_run is $prune_dry_run. no archives will be pruned. check logs to see calculated prune results for vms." "prune_dry_run is ON" "warning"
    else

      if [[ "$enable_prune" -eq 1 ]]; then
        log_message "prune_dry_run is $prune_dry_run and enable_prune is $enable_prune. archives may be pruned based on prune parameters."
      fi

    fi

  else

    log_message "prune_dry_run is $prune_dry_run. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'prune_dry_run'" "alert"
    exit 1

  fi

  if [[ "$prune_dry_run" -eq 1 || "$enable_prune" -eq 1 ]]; then

    if [[ -z "$keep_within" ]]; then
      log_message "keep_within is empty. skipping."
    elif [[ "$keep_within" =~ ^[1-9][0-9]*(H|d|w|m|y)$ ]]; then
      log_message "keep_within is $keep_within. archives within $keep_within will be pruned."
    else

      log_message "keep_within is $keep_within. expecting empty string or <int><char>. Where <int> - integer, <char> - one of ('H', 'd', 'w', 'm', 'y'). exiting." "invalid format for option 'keep_within'" "alert"
      exit 1
    
    fi

    if [[ -z "$keep_hourly" ]]; then
      log_message "keep_hourly is empty. skipping."
    elif [[ "$keep_hourly" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_hourly is $keep_hourly."
    else

      log_message "keep_hourly is $keep_hourly. expecting integer with minimum value of 1." "invalid format for option 'keep_hourly'" "alert"
      exit 1

    fi

    if [[ -z "$keep_daily" ]]; then
      log_message "keep_daily is empty. skipping."
    elif [[ "$keep_daily" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_daily is $keep_daily."
    else
      
      log_message "keep_daily is $keep_daily. expecting integer with minimum value of 1." "invalid format for option 'keep_daily'" "alert"
      exit 1

    fi

    if [[ -z "$keep_weekly" ]]; then
      log_message "keep_weekly is empty. skipping."
    elif [[ "$keep_weekly" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_weekly is $keep_weekly."
    else
      
      log_message "keep_weekly is $keep_weekly. expecting integer with minimum value of 1." "invalid format for option 'keep_weekly'" "alert"
      exit 1

    fi

    if [[ -z "$keep_monthly" ]]; then
      log_message "keep_monthly is empty. skipping."
    elif [[ "$keep_monthly" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_monthly is $keep_monthly."
    else
      
      log_message "keep_monthly is $keep_monthly. expecting integer with minimum value of 1." "invalid format for option 'keep_monthly'" "alert"
      exit 1

    fi

    if [[ -z "$keep_yearly" ]]; then
      log_message "keep_yearly is empty. skipping."
    elif [[ "$keep_yearly" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_yearly is $keep_yearly."
    else
      
      log_message "keep_yearly is $keep_yearly. expecting integer with minimum value of 1." "invalid format for option 'keep_yearly'" "alert"
      exit 1

    fi

    if [[ -z "$keep_last_n" ]]; then
      log_message "keep_last_n is empty. skipping."
    elif [[ "$keep_last_n" =~ ^[1-9][0-9]*$ ]]; then
      log_message "keep_last_n is $keep_last_n."
    else
      
      log_message "keep_last_n is $keep_last_n. expecting integer with minimum value of 1." "invalid format for option 'keep_last_n'" "alert"
      exit 1

    fi

    if [[ -z "$keep_within" && -z "$keep_hourly" && -z "$keep_daily" && -z "$keep_weekly" && -z "$keep_monthly" && -z "$keep_yearly" && -z "$keep_last_n" ]]; then
      
      log_message "all prune parameters are empty. no pruning or dry-run pruning will be made."
      enable_prune="0"
      prune_dry_run="0"

    fi

  else
    log_message "prune_dry_run is $prune_dry_run and enable_prune is $enable_prune. skipping prune parameters."
  fi

  if [[ "$should_prune_unhandled_vms_archives" =~ ^(0|1)$ ]]; then 

    if [[ "$should_prune_unhandled_vms_archives" -eq 0 ]]; then
      log_message "should_prune_unhandled_vms_archives is $should_prune_unhandled_vms_archives. archives unhandled by this script execution will be also pruned."
    else
      log_message "should_prune_unhandled_vms_archives is $should_prune_unhandled_vms_archives. archives unhandled by this script execution will not be touched."
    fi

  else

    log_message "should_prune_unhandled_vms_archives is $should_prune_unhandled_vms_archives. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'should_prune_unhandled_vms_archives'" "alert"
    exit 1

  fi

  if [[ "$unhandled_vms_archives_warn" =~ ^(0|1)$ ]]; then 

    if [[ "$unhandled_vms_archives_warn" -eq 0 ]]; then
      log_message "unhandled_vms_archives_warn is $unhandled_vms_archives_warn. information severity will be used if unhandled vms will be detected."
    else
      log_message "unhandled_vms_archives_warn is $unhandled_vms_archives_warn. warning severity will be used if unhandled vms will be detected."
    fi

  else

    log_message "unhandled_vms_archives_warn is $unhandled_vms_archives_warn. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'unhandled_vms_archives_warn'" "alert"
    exit 1

  fi


  #### advanced variables ####

  # if snapshots are enabled, then check for a valid extension and add it to the extensions to skip.
  if [ "$use_snapshots" -eq 1 ]; then

    # check to see if snapshot extension is empty. if yes, continue. if no exit.
    if [[ -n "$snapshot_extension" ]]; then

      # remove any leading decimals from the extension.
      snapshot_extension="${snapshot_extension##.}"
      log_message "snapshot_extension is $snapshot_extension. continuing."

    else

      log_message "snapshot_extension is not set. exiting." "option 'snapshot_extension' is not set" "alert"
      exit 1

    fi

    # add snapshot extension to extensions_to_skip if it is not already present.
    # initialize variable snap_exists as false
    snap_exists=false

    # for each extension check to see if it is already in the array.
    for extension in $vdisk_extensions_to_skip; do

      # if the extension already exists in the array set snap_exists to true and break out of the current loop.
      if [ "$extension" == "$snapshot_extension" ]; then

        snap_exists=true
        break

      fi

    done

    # if snapshot extension was not found in the array, add it. else move on.
    if [ "$snap_exists" = false ]; then

      vdisk_extensions_to_skip="$vdisk_extensions_to_skip"$'\n'"$snapshot_extension"
      log_message "snapshot extension not found in vdisk_extensions_to_skip. extension was added."

    else

      log_message "snapshot extension was not found in vdisk_extensions_to_skip. moving on."

    fi

  else

    log_message "use_snapshots disabled, not adding snapshot_extension to vdisk_extensions_to_skip."

  fi

  # check to see if snapshots should fallback to standard backups. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$snapshot_fallback" =~ ^(0|1)$ ]]; then

    if [ "$snapshot_fallback" -eq 0 ]; then
      log_message "snapshot_fallback is $snapshot_fallback. snapshots will fallback to standard backups."
    elif [ "$snapshot_fallback" -eq 1 ]; then
      log_message "snapshot_fallback is $snapshot_fallback. snapshots will not fallback to standard backups."
    fi

  else

    log_message "snapshot_fallback is $snapshot_fallback. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'snapshot_fallback'" "alert"
    exit 1

  fi

  # check to see if vms should be paused instead of shutdown. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$pause_vms" =~ ^(0|1)$ ]]; then

    if [ "$pause_vms" -eq 0 ]; then
      log_message "pause_vms is $pause_vms. vms will be shutdown for standard backups."
    elif [ "$pause_vms" -eq 1 ]; then

      vm_desired_state="paused"
      log_message "pause_vms is $pause_vms. vms will be paused for standard backups."
    
    fi

  else

    log_message "pause_vms is $pause_vms. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'pause_vms'" "alert"
    exit 1

  fi

  # check to see if reconstruct write should be enabled during backup. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$enable_reconstruct_write" =~ ^(0|1)$ ]]; then

    if [ "$enable_reconstruct_write" -eq 0 ]; then
      log_message "enable_reconstruct_write is $enable_reconstruct_write. reconstruct write will not be enabled by this script."
    elif [ "$enable_reconstruct_write" -eq 1 ]; then
      log_message "enable_reconstruct_write is $enable_reconstruct_write. reconstruct write will be enabled during the backup."
    fi

  else

    log_message "enable_reconstruct_write is $enable_reconstruct_write. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'enable_reconstruct_write'" "alert"
    exit 1

  fi

  # check to see if config should be backed up. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$backup_xml" =~ ^(0|1)$ ]]; then

    if [ "$backup_xml" -eq 0 ]; then
      log_message "backup_xml is $backup_xml. vms will not have their xml configurations backed up."
    elif [ "$backup_xml" -eq 1 ]; then
      log_message "backup_xml is $backup_xml. vms will have their xml configurations backed up."
    fi

  else

    log_message "backup_xml is $backup_xml. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'backup_xml'" "alert"
    exit 1

  fi


  # check to see if nvram should be backed up. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$backup_nvram" =~ ^(0|1)$ ]]; then

    if [ "$backup_nvram" -eq 0 ]; then
      log_message "backup_nvram is $backup_nvram. vms will not have their nvram backed up."
    elif [ "$backup_nvram" -eq 1 ]; then
      log_message "backup_nvram is $backup_nvram. vms will have their nvram backed up."
    fi

  else

    log_message "backup_nvram is $backup_nvram. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'backup_nvram'" "alert"
    exit 1

  fi


  # check to see if vdisks should be backed up. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$backup_vdisks" =~ ^(0|1)$ ]]; then

    if [ "$backup_vdisks" -eq 0 ]; then
      log_message "backup_vdisks is $backup_vdisks. vms will not have their vdisks backed up. compression will be set to off."
    elif [ "$backup_vdisks" -eq 1 ]; then
      log_message "backup_vdisks is $backup_vdisks. vms will have their vdisks backed up."
    fi

  else

    log_message "backup_vdisks is $backup_vdisks. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'backup_vdisks'" "alert"
    exit 1

  fi


  # check to see if vms should be started after a successful backup. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$start_vm_after_backup" =~ ^(0|1)$ ]]; then

    if [ "$start_vm_after_backup" -eq 0 ]; then
      log_message "start_vm_after_backup is $start_vm_after_backup. vms will not be started following successful backup."
    elif [ "$start_vm_after_backup" -eq 1 ]; then
      log_message "start_vm_after_backup is $start_vm_after_backup vms will be started following a successful backup."
    fi

  else

    log_message "start_vm_after_backup is $start_vm_after_backup. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'start_vm_after_backup'" "alert"
    exit 1

  fi


  # check to see if vms should be started after an unsuccessful backup. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$start_vm_after_failure" =~ ^(0|1)$ ]]; then

    if [ "$start_vm_after_failure" -eq 0 ]; then
      log_message "start_vm_after_failure is $start_vm_after_failure. vms will not be started following an unsuccessful backup."
    elif [ "$start_vm_after_failure" -eq 1 ]; then
      log_message "start_vm_after_failure is $start_vm_after_failure. vms will be started following an unsuccessful backup."
    fi

  else

    log_message "start_vm_after_failure is $start_vm_after_failure. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'start_vm_after_failure'" "alert"
    exit 1

  fi

  # check to see how many times vm's state should be checked for shutdown. if yes, continue if no, continue if input invalid, exit.
  if [[ "$clean_shutdown_checks" =~ ^[0-9]+$ ]]; then

    if [ "$clean_shutdown_checks" -lt 5 ]; then
      log_message "clean_shutdown_checks is $clean_shutdown_checks. this is potentially an insufficient number of shutdown checks."
    elif [ "$clean_shutdown_checks" -gt 50 ]; then
      log_message "clean_shutdown_checks is $clean_shutdown_checks. this is a vast number of shutdown checks."
    elif [ "$clean_shutdown_checks" -ge 5 ] && [ "$clean_shutdown_checks" -le 50 ]; then
      log_message "clean_shutdown_checks is $clean_shutdown_checks. this is probably a sufficient number of shutdown checks."
    fi

  else

    log_message "clean_shutdown_checks is $clean_shutdown_checks. this is not a valid format. expecting a number between [0 - 1000000]. exiting." "invalid format for option 'clean_shutdown_checks'" "alert"
    exit 1

  fi


  # check to see how many seconds to wait between vm shutdown checks. messages to user only. if input invalid, exit.
  if [[ "$seconds_to_wait" =~ ^[0-9]+$ ]]; then

    if [ "$seconds_to_wait" -lt 30 ]; then
      log_message "seconds_to_wait is $seconds_to_wait. this is potentially an insufficient number of seconds to wait between shutdown checks."
    elif [ "$seconds_to_wait" -gt 600 ]; then
      log_message "seconds_to_wait is $seconds_to_wait. this is a vast number of seconds to wait between shutdown checks."
    elif [ "$seconds_to_wait" -ge 30 ] && [ "$seconds_to_wait" -le 600 ]; then
      log_message "seconds_to_wait is $seconds_to_wait. this is probably a sufficient number of seconds to wait between shutdown checks."
    fi

  else

    log_message "seconds_to_wait is $seconds_to_wait. this is not a valid format. expecting a number between [0 - 1000000]. exiting." "invalid format for option 'seconds_to_wait'" "alert"
    exit 1

  fi


  # check to see if error log files should be kept. if yes, continue. if no, continue. if input invalid, exit.
  if [[ "$keep_error_log_file" =~ ^(0|1)$ ]]; then

    if [ "$keep_error_log_file" -eq 0 ]; then
      log_message "keep_error_log_file is $keep_error_log_file. error log files will not be kept."
    elif  [ "$keep_error_log_file" -eq 1 ]; then
      log_message "keep_error_log_file is $keep_error_log_file. error log files will be kept."
    fi

  else

    log_message "keep_error_log_file is $keep_error_log_file. this is not a valid format. expecting [0 = no] or [1 = yes]. exiting." "invalid format for option 'keep_error_log_file'" "alert"
    exit 1

  fi


  # check to see how many error log files should be kept. if yes, continue if no, continue if input invalid, exit.
  if [[ "$number_of_error_log_files_to_keep" =~ ^[0-9]+$ ]]; then

    if [ "$number_of_error_log_files_to_keep" -lt 2 ]; then

      if [ "$number_of_error_log_files_to_keep" -eq 0 ]; then
        log_message "number_of_error_log_files_to_keep is $number_of_error_log_files_to_keep. an infinite number of error log files will be kept. be sure to pay attention to how many error log files there are."
      else
        log_message "number_of_error_log_files_to_keep is $number_of_error_log_files_to_keep. this is potentially an insufficient number of error log files to keep."
      fi

    elif [ "$number_of_error_log_files_to_keep" -gt 40 ]; then
      log_message "number_of_error_log_files_to_keep is $number_of_error_log_files_to_keep. this is a error lot of log files to keep."
    elif [ "$number_of_error_log_files_to_keep" -ge 2 ] && [ "$number_of_error_log_files_to_keep" -le 40 ]; then
      log_message "number_of_error_log_files_to_keep is $number_of_error_log_files_to_keep. this is probably a sufficient error number of log files to keep."
    fi

  else

    log_message "number_of_error_log_files_to_keep is $number_of_error_log_files_to_keep. this is not a valid format. expecting a number between [0 - 1000000]. exiting." "invalid format for option 'number_of_error_log_files_to_keep'" "alert"
    exit 1

  fi

#### validate user variables end ####

  
#### code execution start ####

  # set this to force the for loop to split on new lines and not spaces.
  IFS=$'\n'

  # check to see if backup_all_vms is enabled.
  if [ "$backup_all_vms" -eq 1 ]; then
    
    # since we are using backup_all_vms, ignore any vms listed in vms_to_backup.
    vms_to_ignore="$vms_to_backup"

    # unset vms_to_backup
    unset -v vms_to_backup

    # get a list of the vm names installed on the system.
    vm_exists=$(virsh list --all --name)

    # check each vm on the system against the list of vms to ignore.
    for vmname in $vm_exists; do

      # assume the vm will not be ignored until it is found in the list of vms to ignore.
      ignore_vm=false

      for vm in $vms_to_ignore; do

        if [ "$vmname" == "$vm" ]; then

          # mark the vm as needing to be ignored.
          ignore_vm=true

          # skips current loop.
          continue

        fi

      done

      # if vm should not be ignored, add it to the list of vms to backup.
      if [[ "$ignore_vm" = false ]]; then

        if [[ -z "$vms_to_backup" ]]; then
          vms_to_backup="$vmname"
        else
          vms_to_backup="$vms_to_backup"$'\n'"$vmname"
        fi

      fi

    done

  fi

  # create comma separated list of vms to backup for log file.
  for vm_to_backup in $vms_to_backup; do

    if [[ -z "$vms_to_backup_list" ]]; then
      vms_to_backup_list="$vm_to_backup"
    else
      vms_to_backup_list="$vms_to_backup_list, $vm_to_backup"
    fi

  done

  log_message "started attempt to backup $vms_to_backup_list to repository"

  # check to see if reconstruct write should be enabled by this script. if so, enable and continue.
  if [ "$enable_reconstruct_write" -eq 1 ]; then

    /usr/local/sbin/mdcmd set md_write_method 1
    log_message "Reconstruct write enabled."

  fi

  # create directory for logs.
  if [ ! -d "$logs_folder" ] ; then

    log_message "$logs_folder does not exist. creating it."

    # make the directory as it doesn't exist. added -v option to give a confirmation message to command line.
    mkdir -vp "$logs_folder"

  else

    log_message "$logs_folder exists. continuing."

  fi

  # bool that indicates an error with prune of any vm or not. by default expected that all vms successfully pruned
  all_vms_succ_pruned="y"

  # loop through the vms in the list and try and back up their associated configs and vdisk(s).
  for vm in $vms_to_backup; do

    # get a list of the vm names installed on the system.
    vm_exists=$(virsh list --all --name)

    # assume the vm is not going to be backed up until it is found on the system
    skip_vm="y"

    # check to see if the vm exists on the system to backup.
    for vmname in $vm_exists; do

      # if the vm doesn't match then set the skip flag to y.
      if [ "$vm" == "$vmname" ]; then

        # set a flag i am going to check later to indicate if i should skip this vm or not.
        skip_vm="n"

        # skips current loop.
        break

      fi

    done

    # if the skip flag was set in the previous section then we have to exit and move on to the next vm in the list.
    if [ "$skip_vm" == "y" ]; then

      log_message "$vm can not be found on the system. skipping vm." "script skipping $vm" "warning"
      skip_vm="n"
      continue

    else
      log_message "$vm can be found on the system. attempting backup."
    fi

    # see if a config file exists for the vm already and remove it.
    if [[ -f "$vm.xml" ]]; then
      
      log_message "removing old local $vm.xml."
      rm -fv "$vm.xml"
    
    fi

    # dump the vm config locally.
    log_message "creating local $vm.xml to work with during backup."
    virsh dumpxml "$vm" > "$vm.xml"

    # replace xmlns value with absolute URI to avoid namespace warning.
    # sed isn't an ideal way to edit xml files, but few options are available on unraid.
    # this only edits a temporary file that is removed at the end of the script.
    sed -i 's|vmtemplate xmlns="unraid"|vmtemplate xmlns="http://unraid.net/xmlns"|g' "$vm.xml"

    # extract vm uuid from config file.
    vm_uuid=$(xmllint --xpath "string(/domain/uuid)" "$vm.xml")
    vms_uuid+=("$vm_uuid")

    if [ "$enable_vm_log_file" -eq 1 ]; then
      
      mkdir -vp "$logs_folder$vm/"
      vm_log_file="$logs_folder$vm/$timestamp-unraid-vmbackup.log"

    fi

    # get the state of the vm for making sure it is off before backing up.
    vm_state=$(virsh domstate "$vm")

    # get the state of the vm for putting the VM in it's original state after backing up.
    vm_original_state=$vm_state

    # initialize skip_vm_shutdown variable as false.
    skip_vm_shutdown=false

    # determine if vm should be kept running.
    # first check to see if vm exists in vms_to_backup_running variable.
    for vm_to_keep_running in $vms_to_backup_running; do

      if [[ "$vm_to_keep_running" == "$vm" ]]; then
        skip_vm_shutdown=true
      fi

    done

    # start backing up vm configuration, nvram, and snapshots.
    log_message "starting backup of $vm configuration, nvram, and vdisk(s)." "script starting $vm backup" "normal"

    # unset and init paths_to_archive
    unset paths_to_archive
    paths_to_archive=()

    # see if config should be backed up.
    if [[ "$backup_xml" -eq 1 ]]; then

      # append vm xml config absolute path.
      paths_to_archive+=( "$(readlink -f "$vm.xml")" )
      log_message "backup_xml is $backup_xml. added xml config at $(readlink -f "$vm.xml") for $vm to vm backup"
    fi

    # see if nvram should be backed up.
    if [[ "$backup_nvram" -eq 1 ]]; then

      # extract nvram path from config file.
      nvram_path=$(xmllint --xpath "string(/domain/os/nvram)" "$vm.xml")

      # check to see if nvram_path is empty.
      if [[ -z "$nvram_path" ]]; then
        log_message "backup_nvram is $backup_nvram. $vm does not appear to have an nvram file. skipping."
      else

        # append vm nvram absolute path.
        paths_to_archive+=( "$nvram_path" )
        log_message "backup_nvram is $backup_nvram. added nvram at $nvram_path for $vm to vm backup"
      fi

    fi

    get_vm_vdisks

    # see if vdisks should be backed up and there vdisks to backup.
    if [[ "$backup_vdisks" -eq 1 && ${#vdisks_path[@]} -ne 0 ]]; then

      log_message "backup_vdisks is $backup_vdisks. start vm preparing for disks backup."
      
      # if vm is not found in vms_to_backup_running and use_snapshots is disabled, then prepare vm.
      if [ "$skip_vm_shutdown" = false ] && [ "$use_snapshots" -eq 0 ]; then

        log_message "skip_vm_shutdown is false. beginning vm shutdown procedure."

        # prepare vm for backup.
        if ! prepare_vm "$vm" "$vm_state"; then
          
          log_message "skipping $vm."
          continue
        
        fi

      elif [[ "$use_snapshots" -eq 1 && "$vm_state" == "running" ]]; then

        take_vm_snapshot
        snapshot_rc=$?


        if [[ "$snapshot_rc" -ne 0 && "$skip_vm_shutdown" = true ]]; then
          log_message "failed to take snapshot for $vm. skip_vm_shutdown is $skip_vm_shutdown. continue backup process."
        
        # attempt backup using fallback method on snapshot failure.
        elif [[ "$snapshot_rc" -ne 0 && "$snapshot_fallback" -eq 1 ]]; then
          
          log_message "snapshot_fallback is $snapshot_fallback. attempting to backup $vm using fallback method." "$vm fallback backup" "warning"
          
          if ! perform_snapshot_fallback; then
            
            log_message "failed to perform snapshot fallback. cannot continue vm backup. skipping $vm." "vm backup failed for $vm" "alert"
            continue

          fi

        elif [[ "$snapshot_rc" -ne 0 && "$snapshot_fallback" -eq 0 && "$skip_vm_shutdown" = false ]]; then
          
          log_message "failed to perform snapshot. snapshot_fallback is $snapshot_fallback. skip_vm_shutdown is $skip_vm_shutdown. cannot continue vm backup. skipping $vm." "vm backup failed for $vm" "alert"
          continue

        fi
      
      elif [[ "$use_snapshots" -eq 1 && ! "$vm_state" == "running" && "$skip_vm_shutdown" = false ]]; then
      
        log_message "unable to perform disks snapshots for $vm. falling back to traditional backup. use_snapshots is $use_snapshots. vm_state is $vm_state. skip_vm_shutdown is $skip_vm_shutdown"

        if ! perform_snapshot_fallback; then
          
          log_message "failed to perform snapshot fallback. cannot continue vm backup. skipping $vm." "vm backup failed for $vm" "alert"
          continue

        fi

      elif [[ "$skip_vm_shutdown" = true ]]; then
        log_message "skip_vm_shutdown is $skip_vm_shutdown. will perform disks backup as is."
      fi

      # if after vm and disks preparations vm_sate is shut off, then we can lock disks to prevent from damaging disks in archive that will be created
      if [[ "$vm_state" == "shut off" ]]; then lock_vm_disks; fi

      log_message "successfully prepared vm and disk for backup."

      # add disks paths what should be backed up
      for disk in "${vdisks_path[@]}"; do
        
        paths_to_archive+=( "$disk" )
        log_message "added disk at $disk for $vm to vm backup"
      
      done

    # if vdisk should be backed up, but there's no vdisk then warn about this
    elif [[ "$backup_vdisks" -eq 1 && ${#vdisks_path[@]} -eq 0 ]]; then
      log_message "backup_vdisks is $backup_vdisks. there are no vdisk(s) associated with $vm to backup." "no vdisk(s) for $vm" "warning"
    fi

    # all files paths for archive are collected. perform archive.
    perform_archive "${paths_to_archive[@]}"

    # if snapshot was used, then commit him
    if [[ "$backup_vdisks" -eq 1 && "$use_snapshots" -eq 1 ]]; then
      commit_vm_snapshot "$vm"
    fi

    if [[ "$backup_vdisks" -eq 1 && "$vm_state" == "shut off" ]]; then
      unlock_vm_disks
    fi

    # check to see if set_vm_to_original_state is 1 and then check the vm's original state.
    if [[ "$set_vm_to_original_state" -eq 1 ]]; then

      # get the current state of the vm for checking against its original state.
      vm_state=$(virsh domstate "$vm")

      # start the vm after backup based on previous state.
      if [[ ! "$vm_state" == "$vm_original_state" && "$vm_original_state" == "running" ]]; then

        log_message "vm_state is $vm_state. vm_original_state is $vm_original_state. starting $vm." "script starting $vm" "normal"

        if [[ "$vm_state" == "paused" ]]; then
          virsh resume "$vm"
        elif [[ "$vm_state" == "shut off" ]]; then
          virsh start "$vm"
        else
          log_message "vm_state is $vm_state. vm_original_state is $vm_original_state. unable to start $vm." "script cannot start $vm" "warning"

        fi

      else
        log_message "vm_state is $vm_state. vm_original_state is $vm_original_state. not starting $vm." "script not starting $vm" "normal"
      fi

    fi


    # if start_vm_after_backup is set to 1 then start the vm but don't check that it has been successful.
    if [[ "$start_vm_after_backup" -eq 1 ]]; then

      log_message "vm_state is $vm_state. start_vm_after_backup is $start_vm_after_backup. starting $vm." "script starting $vm" "normal"

      if [[ "$vm_state" == "paused" ]]; then
        virsh resume "$vm"
      elif [[ "$vm_state" == "shut off" ]]; then
        virsh start "$vm"
      else
        log_message "vm_state is $vm_state. vm_original_state is $vm_original_state. unable to start $vm." "script cannot start $vm" "warning"

      fi
    fi

    log_message "backup of $vm to repository completed." "script completed $vm backup" "normal"
    
    if [[ "$enable_prune" -eq 1 || "$prune_dry_run" -eq 1 ]]; then
      
      prune_vm_archives "$vm" "$vm_uuid"
      prune_rc=$?
      
      if [[ $prune_rc -ne 0 ]]; then
        all_vms_succ_pruned="n"
      fi
    
    fi

    unset vm_log_file

    # delete the working copy of the config.
    log_message "removing local $vm.xml."
    rm -fv "$vm.xml"

  done

  log_message "finished attempt to backup and prune $vms_to_backup_list in repository."

  if [[ $all_vms_succ_pruned == "n" ]]; then
    log_message "failed to prune some of vms from vms_to_backup_list. check logs for details" "pruning finished with errors" "warning"
  fi


  # after processing vms do prune of unhandled vms if needed
  if [[ "$enable_prune" -eq 1 || "$prune_dry_run" -eq 1 ]] && [[ "$should_prune_unhandled_vms_archives" -eq 1 ]]; then
      
    prune_unhandled_vms_archives
    prune_rc=$?
    
    if [[ $prune_rc -eq 0 ]]; then
      log_message "successfully pruned archives of unhandled vms."
    else
      log_message "failed to prune some archives of  unhandled vms. check logs for details." "unhandled vms prune failure" "warning"
    fi
    
  fi

  # check to see if reconstruct write was enabled by this script. if so, disable and continue.
  if [ "$enable_reconstruct_write" -eq 1 ]; then

    /usr/local/sbin/mdcmd set md_write_method 0
    log_message "Reconstruct write disabled."

  fi

  # check to see if log file should be kept.
  if [ "$keep_log_file" -eq 1 ]; then

    if [ "$number_of_log_files_to_keep" -eq 0 ]; then
      log_message "number of logs to keep set to infinite."
    else

      log_message "cleaning out logs over $number_of_log_files_to_keep."

      # create variable equal to number_of_log_files_to_keep plus one to make sure that the correct number of files are kept.
      log_files_plus_1=$((number_of_log_files_to_keep + 1))

      # remove log files that are over the limit.
      if [ "$detailed_notifications" -eq 1 ] && [ "$send_notifications" -eq 1 ] && [ "$only_err_and_warn_notif" -eq 0 ]; then

        deleted_files=$(find "$logs_folder"*unraid-vmbackup.log -type f -printf '%T@\t%p\n' | sort -t $'\t' -gr | tail -n +$log_files_plus_1 | cut -d $'\t' -f 2- | xargs -d '\n' -r rm -fv --)

        if [[ -n "$deleted_files" ]]; then

          for deleted_file in $deleted_files; do
            log_message "$deleted_file." "script removing logs" "normal"
          done

        else
          log_message "did not find any log files to remove." "script removing logs" "normal"
        fi

      else

        deleted_files=$(find "$logs_folder"*unraid-vmbackup.log -type f -printf '%T@\t%p\n' | sort -t $'\t' -gr | tail -n +$log_files_plus_1 | cut -d $'\t' -f 2- | xargs -d '\n' -r rm -fv --)

        if [[ -n "$deleted_files" ]]; then

          for deleted_file in $deleted_files; do
            log_message "$deleted_file."
          done

        else
          log_message "did not find any log files to remove."
        fi

      fi

    fi

  fi

  # check to see if error log file should be kept.
  if [ "$keep_error_log_file" -eq 1 ]; then

    if [ "$number_of_error_log_files_to_keep" -eq 0 ]; then
      log_message "number of error logs to keep set to infinite."
    else

      log_message "cleaning out error logs over $number_of_error_log_files_to_keep."

      # create variable equal to number_of_error_log_files_to_keep plus one to make sure that the correct number of files are kept.
      error_log_files_plus_1=$((number_of_error_log_files_to_keep + 1))

      # remove error log files that are over the limit.
      if [ "$detailed_notifications" -eq 1 ] && [ "$send_notifications" -eq 1 ] && [ "$only_err_and_warn_notif" -eq 0 ]; then

        deleted_files=$(find "$logs_folder"*unraid-vmbackup_error.log -type f -printf '%T@\t%p\n' | sort -t $'\t' -gr | tail -n +$error_log_files_plus_1 | cut -d $'\t' -f 2- | xargs -d '\n' -r rm -fv --)

        if [[ -n "$deleted_files" ]]; then

          for deleted_file in $deleted_files; do
            log_message "$deleted_file." "script removing error logs" "normal"
          done

        else
          log_message "did not find any error log files to remove." "script removing error logs" "normal"
        fi

      else

        deleted_files=$(find "$logs_folder"*unraid-vmbackup_error.log -type f -printf '%T@\t%p\n' | sort -t $'\t' -gr | tail -n +$error_log_files_plus_1 | cut -d $'\t' -f 2- | xargs -d '\n' -r rm -fv --)

        if [[ -n "$deleted_files" ]]; then

          for deleted_file in $deleted_files; do
            log_message "$deleted_file."
          done

        else
          log_message "did not find any error log files to remove."
        fi

      fi

    fi

  fi

  # check to see if there were any errors.
  if [ "$errors" -eq 1 ]; then

    log_message "errors found. creating error log file."
    rsync -av "$logs_folder$timestamp""unraid-vmbackup.log" "$logs_folder$timestamp""unraid-vmbackup_error.log"

    # get rsync result and send notification
    if [[ $? -eq 1 ]]; then
      log_message "$logs_folder$timestamp""unraid-vmbackup_error.log create failed." "error log create failed" "alert"
    fi

  fi

  # check to see if log file should be removed.
  if [ "$keep_log_file" -eq 0 ]; then

    if [ "$errors" -eq 1 ] && [ "$keep_error_log_file" -eq 1 ]; then

      echo "$(date '+%Y-%m-%d %H:%M:%S') warning: removing log file." | tee -a "$logs_folder$timestamp""unraid-vmbackup_error.log"
      rm -fv "$logs_folder$timestamp""unraid-vmbackup.log"

    else

      log_message "removing log file."
      rm -fv "$logs_folder$timestamp""unraid-vmbackup.log"

    fi

  fi

  # check to see if error log file should be removed.
  if [ "$keep_error_log_file" -eq 0 ]; then

    if [ "$keep_log_file" -eq 1 ]; then

      log_message "removing error log file."
      rm -fv "$logs_folder$timestamp""unraid-vmbackup_error.log"

    else

      notification_message "removing error log file."
      rm -fv "$logs_folder$timestamp""unraid-vmbackup_error.log"

    fi

  fi

  ### Logging Stopped ###
  if [ "$keep_log_file" -eq 1 ]; then
    log_message "Stop logging to log file."
  fi

  if [ "$errors" -eq 1 ] && [ "$keep_error_log_file" -eq 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Stop logging to error log file."  | tee -a "$logs_folder$timestamp""unraid-vmbackup_error.log"
  fi


  if [ "$send_notifications" -eq 1 ]; then

    if [ "$errors" -eq 1 ]; then
      /usr/local/emhttp/plugins/dynamix/scripts/notify -e "unraid-vmbackup_error" -s "unRAID Borg VM Backup" -d "script finished with errors" -i "alert" -m "$(date '+%Y-%m-%d %H:%M:%S') warning: unRAID Borg VM Backup finished with errors. See log files in $logs_folder for details."
    elif [ "$only_err_and_warn_notif" -eq 0 ]; then
      /usr/local/emhttp/plugins/dynamix/scripts/notify -e "unraid-vmbackup_finished" -s "unRAID Borg VM Backup" -d "script finished" -i "normal" -m "$(date '+%Y-%m-%d %H:%M:%S') unRAID Borg VM Backup finished. See log files in $logs_folder for details."
    fi

  fi

  exit 0

#### code execution end ####

##############################################
################# script end #################
##############################################