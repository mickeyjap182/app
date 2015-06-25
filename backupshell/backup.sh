#!/bin/bash

#################################################
# backup.sh
# 
# ----------------------------------------------
# Copyright (c) 2015 Yoshitaka Toyama <yoshitaka_8an9drums@msn.com>
# 
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
# ----------------------------------------------
# Overview; 
#   this tool takes back up tool by dump on dialogue.
#   you must use carefully, or you will lose your OS data!
# 2015.06.25 created 
# ----------------------------------------------
#
# description (what does thie tool do?): 
#
#   0. initial validation
#   1. input a device to save.
#   2. input a device to take backup.
#   3. input a partition to take backup.(@/etc/fstab)
#   4. input which does it take backup for Master Boot Record.
#   5. confirm input contents.(it is possible to modify input contents.)
#   6. This tool executes to take backup.	
# 
# Environment: 
#   debian Linux (Kali Linux 1.1.0)
#
# Require:
#   dump pkg
#
# usage: 
#   please allocate this tool on '/usr/bin' or executable directory as root .
#   # backup.sh 
#       start up diakogue. 
#   # backup.sh -h
#       display usage. 
#
#################################################

#### global variable area #####

# definition of functions. (sort sequencial)
readonly GLOBAL_FUNCTION_LIST=( "init" "choose_save_device" "choose_take_device" "choose_take_directory" "choose_take_mbr" "confirm_input_contents" "execute" )


# a device name to save backup.
global_save_dev=""

# a mount point to mount for saving device.
global_save_mnt="/mnt/backup"

# a directory-path to mount for saving device.
global_save_dir="${global_save_mnt}/backup"

# a devicename name to take backup
global_take_dev="/dev/sda1"

# partitions name to take backup
global_take_dir_list=( "/" )

# do you take Master Boot Record backup?(yes:take. no:don't take)
global_does_take_mbr="no"

# a devicename name to take Master Boot Record backup.
global_take_mbr_dir=""


# commands list to execute on this tool. 
global_command_list=()

# comments list of command. 
global_command_detail_list=()


# display usage 
function usage() {
    echo ""
    echo ""
    echo "usage: "
    echo "  You may allocate '/usr/bin/', when you start up, you do './backup.sh' or 'backup.sh' command."
    echo ""
    echo "  This tool is backup tool by dump as dialogue. It will save a dump file from 'take device' to 'save device'. "
    echo ""
    echo "  you must use carefully, or you will lose your OS data!( I have NO responsibility about this tool...) "
    echo ""
    echo "  futhermore, you must change for runlevel to single user mode. "
    echo ""
    echo "  How does This tool do? Please follow next... "
    echo " "
    echo "   0. initial validation."
    echo "   1. input a device to save."
    echo "   2. input a device to take backup."
    echo "   3. input a partition to take backup.(@/etc/fstab)"
    echo "   4. input which does it take backup for Master Boot Record."
    echo "   5. confirm input contents.(it is possible to modify input contents.)"
    echo "   6. This tool executes to take backup."
    echo ""
    echo "  attention: Until you agree to save backup in 'No.5 confirm input contents', this tool never execute command."
    echo "    and after you take backup, you should test about validation of backup dump."
    echo ""
}

# initial validation.
function init() {

    # return status(0:OK 1:Error 2:Cancel)
    local _result=0

    # validation message
    local _message="OK"
    
    echo ""
    echo ""
    echo "===================1. initial validation.====================="
    echo ""

    # validation of dump
    local _dumpExists=`whereis dump | wc -w`
    if [ ${_dumpExists} -lt 1 ]; then
        echo ""
        echo "warning:You must install [dump]. (apt-get install dump)"
        echo ""
        _result=2
        _message="NG"
    fi
    
    echo "check for [dump] is already installed...${_message}"

    # validation of runlevel
    _message="OK"
    local _runlevel=`runlevel | awk '{print $2}'`
    if [ ${_runlevel} != "S" ]; then
        echo ""
        echo "warning:You must modify a runlevel to [SINGLE USER MODE]. (init 1)"
        echo ""
        _result=2
        _message="NG"
    fi

    echo "check for runlevel:${_runlevel} ...${_message}"

    # If the case environment is incorrect, program will stop.
    if [ ${_result} -ne 0 ]; then
        return ${_result}
    fi

    # validation of dump field in /etc/fstab
    local _valid=1
    local _answer=""
    while [ ${_valid} -ne 0 ]
    do
        cat /etc/fstab
        echo ""
        echo "('/etc/fstab' of current device )"
        echo ""
        echo "==============================================================="
        echo "Is dump field(No5) setting '1'  in '/etc/fstab' of a backup device? "
        echo -n "((y) setting=1   (n) setting=0 or other)"
        read _answer
        case "${_answer}" in 
            "yes" | "y" )
                echo "check for dump field:1 ...OK"
                sleep 1
                _valid=0
                ;;
            "no" | "n" )
                echo ""
                echo "check for dump field: ...NG"
                echo "You confirm dump field(No5) setting '1' in '/etc/fstab' of a backup device"
                echo ""
                sleep 2
                _valid=0
                _result=2
                ;; 
            * ) 
                echo ""
                echo "invalid input!"
                sleep 1
                echo ""
                ;;
        esac
    done
    
    # return status
    return ${_result}
}

# makeup command
function _make_command() {

        # initialize
        global_command_list=()
        global_command_detail_list=()
        
        # change directory to '/'.
        global_command_list[${#global_command_list[@]}]="cd /"
        global_command_detail_list[${#global_command_detail_list[@]}]="# change directory to '/'."

        # mkdir for mount directry
        if [ -e ${global_save_mnt} ]; then
            echo "info:directory to mount: It already exists."
        else
            # a command for 'mkdir to mount device'.
            global_command_list[${#global_command_list[@]}]="mkdir -p ${global_save_mnt}"
            global_command_detail_list[${#global_command_detail_list[@]}]="# mkdir to mount device."
        fi

        # a command for 'mount to save device'.
        global_command_list[${#global_command_list[@]}]="mount -o rw -t ext4 ${global_save_dev} ${global_save_mnt}"
        global_command_detail_list[${#global_command_detail_list[@]}]="# mount to save device."

        # a command for 'mkdir to save dump directory'.
        global_save_dir="${global_save_mnt}/backup"
        if [ -e  ${global_save_dir} ]; then
            echo "info:directory to save backup: It already exists."
        else
            # a command for 'mkdir to save dump directory'.
            global_command_list[${#global_command_list[@]}]="mkdir -p ${global_save_dir}"
            global_command_detail_list[${#global_command_detail_list[@]}]="# mkdir to save dump directory."
        fi

        # a command for 'exclude partitions (/mnt  /tmp) to take backup.'
        global_command_list[${#global_command_list[@]}]="chattr -R +d /mnt /tmp"
        global_command_detail_list[${#global_command_detail_list[@]}]="# exclude partitions (/mnt  /tmp) to take backup."

        # a command for 'confirm directory attribute'.
        global_command_list[${#global_command_list[@]}]="lsattr /mnt /tmp"
        global_command_detail_list[${#global_command_detail_list[@]}]="# confirm directory attribute."

        # a command for 'mount / partition with readable only'.
        global_command_list[${#global_command_list[@]}]="mount -r -n -o remount /"
        global_command_detail_list[${#global_command_detail_list[@]}]="# mount / partition with readable only."

        # It creates prefix as date of today.
        local _today=`date +'%Y%m%d'`

        # a command for taking backup by dump,
        for part in ${global_take_dir_list[@]} 
        do
            # attention: It adds prefix for dump file.
            global_command_list[${#global_command_list[@]}]="dump -b 32 -0f ${global_save_dir}/${_today}${part////_}-kali.dump ${part}"
            global_command_detail_list[${#global_command_detail_list[@]}]="# command of dump to take backup for all."
        done
        
        # a command for 'mount / partition with writable option'.
        global_command_list[${#global_command_list[@]}]="mount -w -n -o remount /"
        global_command_detail_list[${#global_command_detail_list[@]}]="# mount / partition with writable option."

        # a command for MBR.
        if [ ${global_does_take_mbr} == "yes" ]; then
            # take a backup for MBR.
            global_command_list[${#global_command_list[@]}]="dd if=${global_take_mbr_dir} of=${global_save_dir}/${_today}-mbr.img bs=512 count=1"
            global_command_detail_list[${#global_command_detail_list[@]}]="# command of a image copy to take backup for MBR."
        fi
}

# display command
function _disp_command() {

    local _index=0
    echo ""
    echo ""
    echo "===================display executable commands====================="
    echo ""

    for cur_command in ${global_command_list[@]}
    do
        echo "${global_command_detail_list[$_index]}"
        echo "${cur_command}"
        echo ""
        _index=$((${_index} + 1))
    done
    
}

# input a device to save.
function choose_save_device() {

    # return status(0:OK 1:Error 2:Cancel)
    local _result=1
    answer=""

    echo ""
    echo ""
    echo "===========1.TERM: input for [a device to save].========"
    echo ""

    # dialog for input device.
    while [ ${_result} -ne 0 ] 
    do 
        # display device status.
        fdisk -l 

        # display message for input.
        echo ""
        echo "==============================================================="
        echo -n "Please input a device to save and press [enter]. e.g.) /dev/sdb1:"

        # typed value.
        read answer

        # confirm that input value is not empty.
        if [ "${answer}" == "" ]; then
            echo ""
            echo "input [a device to save]."
            echo ""
            sleep 1
            continue
        fi

        # a validation about save device.
        device_list=`fdisk -l | grep -Po "^/dev/\w+"`
        for dev in ${device_list[@]}
        do

            # Is input device a valid device?
            if [ "${answer}" == "${dev}" ]; then 
                echo ""
                echo "[a device to save] is [${answer}]."
                echo ""
                global_save_dev="${answer}"
                _result=0
                sleep 1
                break 
            fi 
        done

        # If it is invalid input, display notice message.
        if [ ${_result} -ne 0 ]; then
            echo ""
            echo "Notice:${answer} doesn't exist..."
            echo ""
            sleep 1
        fi
    done

    # return status(0:OK 1:Error 2:Cancel)
    return ${_result}
}

# input a device to take backup. 
function choose_take_device() {

    # return status(0:OK 1:Error 2:Cancel)
    local _result=1
    answer=""

    echo ""
    echo ""
    echo "===========2.TERM: input for [a device to take backup].=============="
    echo ""

    # dialog for input device.
    while [ ${_result} -ne 0 ] 
    do 

        fdisk -l
        # display message for input.
        echo ""
        echo "==============================================================="
        echo -n "Please choose [a device to take backup]  (current choice:[${global_take_dev}],if you leave it alone, press [enter].) :"

        # typed value.
        read answer

        # when the input value is empty, use default value.
        if [ "${answer}" == "" ]; then
            answer=${global_take_dev}
        fi

        # a validation about save device.
        device_list=`fdisk -l | grep -Po "^/dev/\w+"`
        for dev in ${device_list[@]}
        do
            # Is input device a valid device?
            if [ ${answer} == ${dev} ]; then 
                echo ""
                echo "[a device to take backup] is [${answer}]."
                echo ""
                sleep 1
                global_take_dev="${answer}"
                _result=0
                break 
            fi 
        done

        # If it is invalid input, display notice message.
        if [ ${_result} -ne 0 ]; then
            echo ""
            echo "Notice:${answer} doesn't exist..."
            echo ""
            sleep 1
        fi
    done

    # return status(0:OK 1:Error 2:Cancel)
    return ${_result}
}

# input a partition to take backup.(@/etc/fstab)
function choose_take_directory() {

    # return status. (0:OK 1:Error 2:Cancel)
    local _result=1

    # partition list string.
    local _take_dirstr=""

    # develop partition list from 'array' to 'string'.(delimiter is [space])
    local _take_dir=""
    for _take_dir in ${global_take_dir_list[@]}
    do
        _take_dirstr+="${_take_dir} "
    done
    
    echo ""
    echo ""
    echo "===========3.TERM: input for [partition to take backup].============="
    echo ""

    answer=""

    # dialog for input partition.
    while [ ${_result} -ne 0 ] 
    do 
        # partition list of temporary.
        local _take_dir_list=()

        # display about '/etc/fstab'
        cat /etc/fstab
        echo ""
        echo "Attention: it is current /etc/fstab. if you choose other device, you must confirm."
        echo ""
        
        # display message for input.
        echo ""
        echo "==============================================================="
        echo "Please input a partition to take backup.(current choice: ${take_dirstr}) "
        echo "if current choice is correct, you just press [enter]."
        echo -n "if you choose some partitions, use a space as separater. ) e.g.) / /boot :"

        # typed value.
        read answer

        # when the input value is empty, use default value.
        if [ "${answer}" == "" ]; then
            _take_dir_list=${global_take_dir_list}
        else
            _take_dir_list=(`echo "${answer}"`)
            _take_dirstr=${answer}
        fi

        local _valid=0

        for dir in ${_take_dir_list[@]}
        do
            # Are all partitions valid?  
            if [ -d ${dir} ]; then 
                fstab_exists=`cat /etc/fstab | grep -e "^UUID" | awk '{print $2 }' | grep -e "^${dir}$" | wc -l `
                if [ ${fstab_exists} -eq 1 ]; then
                    continue
                else
                    echo ""
                    echo "Notice: Partition (${dir} ) is invalid. Please input [partition in  '/etc/fstab']."
                    echo ""
                    sleep 2
                    _valid=1
                    break 
                fi
            else
                echo ""
                echo "Notice:Partition ${dir} is invalid. Please input [partition as directory name]. "
                echo ""
                sleep 2
                _valid=1
                break 
            fi 
        done

        # check for validation result.
        if [ ${_valid} -eq 0 ]; then
            _result=0
        fi
    done

    echo ""
    echo "[partition to take backup] is [${_take_dirstr}]."
    echo ""
    sleep 1
    global_take_dir_list=${_take_dir_list}

    # return status. (0:OK 1:Error 2:Cancel)
    return ${_result}
}

# input which does it take backup for Master Boot Record.
function choose_take_mbr() {

    # return status. (0:OK 1:Error 2:Cancel)
    local _result=1

    echo ""
    echo ""
    echo "===========4.TERM: input for [a device whose Master Boot Record to take backup].==========="

    # dialog for input device.
    while [ ${_result} -ne 0 ] 
    do 

        does_take=""
        # display message for input.
        echo ""
        echo "==============================================================="
        echo -n "Do you take backup of Master Boot Record?(yes(y):take, no(n) :don't take):"

        # typed value.
        read does_take

        # Do you take back up of Master Boot Record?
        case ${does_take} in 
            "yes" | "y" )
                global_does_take_mbr="yes"
                echo ""
                echo "Take backup of MBR:yes"
                echo ""
                sleep 1
                _result=0
                ;;
            "no" | "n" )
                global_does_take_mbr="	no"
                echo ""
                echo "Take backup of MBR:no"
                echo ""
                sleep 1
                _result=0
                ;; 
            *) 
                echo -n "invalid input!"
                echo ""
                echo ""
                sleep 1
                ;;
        esac
    done

    # When user choose 'YES', it make him to input backup device.
    if [ ${global_does_take_mbr} == "yes" ]; then
        # return status. (0:OK 1:Error 2:Cancel)
        _result=1
        where_does_take=""

        # when the input value is empty, use devicee of the head of save device.
        if [ "${global_take_mbr_dir}" == "" ]; then
            global_take_mbr_dir=`echo "${global_take_dev}" | grep -Po "^/dev/[A-Za-z]+"`
        fi

        # dialog for input device.
        while [ ${_result} -ne 0 ] 
        do 
            # display device.
            fdisk -l 

            # display message for input.
            echo ""
            echo "==============================================================="
            echo "Please input a device of Master Boot Record. e.g.) /dev/sdb (current choice: ${global_take_mbr_dir})"
            echo -n "if current choice is correct, you just press [enter]) :"

            # typed value.
            read where_does_take

            # when the input value is empty, use default value.
            if [ "${where_does_take}" == "" ]; then
                where_does_take=${global_take_mbr_dir}
            fi

            # a validation about MBR of save device.
            device_list=`fdisk -l | grep -Po "^/dev/\w+"`
            for dev in ${device_list[@]}
            do
                # is b validation about MBR of save device.
                if [ ${where_does_take} == `echo "${dev}" | grep -Po "^/dev/[A-Za-z]+"` ]; then 
                    _result=0
                    echo ""
                    echo "a device of Master Boot Record to take backup is [${where_does_take}]."
                    echo ""
                    global_take_mbr_dir="${where_does_take}"
                    break 
                fi 
                echo ""
                echo "Notice:${where_does_take} は存在しません。"
                echo ""
            done
        done
    fi

    # return status. (0:OK 1:Error 2:Cancel)
    return ${_result}
}

# confirm input contents.(it is possible to modify input contents.)
function confirm_input_contents() {

    # return status. (0:OK 1:Error 2:Cancel)
    local _result=1

    # partition list string.
    local _take_dirstr=""

    # dialog for input device.
    while [ ${_result} -ne 0 ] 
    do 

        answer=""
        # change the array delimiter to 'line feed'.
        export IFS_BK=${IFS}
        export IFS=$'\n'

        #### 5. confirm input contents.(it is possible to modify input contents.) ####
        # make and display
        _make_command

        _disp_command

        # restore the array delimiter to 'space'.
        export IFS=${IFS_BK}

        echo "===================TERM: RECONFIRM====================="
        # 1. input a device to save.
        echo "  1.Change [a device to save] [current: ${global_save_dev}]"
        
        # 2. input a device to take backup.
        echo "  2.Change [a device to take backup] [current: ${global_take_dev}]"

        # 3. input a partition to take backup.(@/etc/fstab)
        local _take_dir=""
        local _take_dirstr=""
        for _take_dir in ${global_take_dir_list[@]}
        do
            _take_dirstr+="${_take_dir} "
        done
        echo "  3.Change [partition to take backup] [current: ${_take_dirstr}]"

        # 4. input which does it take backup for Master Boot Record.
        if [ ${global_does_take_mbr} == "no" ]; then 
            echo "  4.Change [to take a backup for Master Boot Record] [current: Never take backup)"
        else
            echo "  4.Change [a device whose Master Boot Record to take backup] [current: ${global_take_mbr_dir})"
        fi

        # 8.display commands
        echo "  8.repeat to display commands."

        # 9.DECIDE to execute.
        echo "  9.DECIDE to execute."
        
        # 0.CANCEL to execute.
        echo "  0.CANCEL to execute."

        # dialog for choosing action.
        echo ""
        echo "==============================================================="
        echo -n "Please choose a number of menu. (0-9):"

        # input value.
        read answer

        # This tool act roll depend on your input.
        case ${answer} in
            1 | 2 | 3 | 4 )
                ${GLOBAL_FUNCTION_LIST[${answer}]}
                sleep 1
                ;;
            8 )
                continue
                ;;
            9 )
                is_executable=""
                echo ""
                echo -n "Are you sure to 'TAKE BACKUP' by dump? (y(yes):sure, I do.   n(no):not, I don't.)"
                read is_executable
                case ${is_executable} in 
                    "y" | "yes" )
                        echo ""
                        echo "START... please wait for a while..."
                        echo ""
                        _result=0
                        sleep 1
                        ;;
                    "n" | "no" )
                        echo ""
                        echo "cancel to take backup and go back menu ..."
                        echo ""
                        sleep 1
                        ;;
                    * )
                        echo ""
                        echo "Invalid input..."
                        echo ""
                        sleep 1
                        ;;
                esac
                ;;
            0 )
                echo -n "Are you sure to 'EXIT THIS TOOL' ? (y(yes):sure, I do.   n(no):not, I don't.)"
                read is_executable
                case ${is_executable} in 
                    "y" | "yes" )
                        echo ""
                        echo "Exiting...please wait a moment..."
                        echo ""
                        sleep 1
                        return 2
                        ;;
                    "n" | "no" )
                        echo ""
                        echo "cancel to exit this tool and go back menu ...."
                        echo ""
                        sleep 1
                        ;;
                    * )
                        echo ""
                        echo "Invalid input..."
                        echo ""
                        sleep 1
                        ;;
                esac
                ;;
            * )
                echo ""
                echo "Invalid input. please press valid [number]."
                echo ""
                sleep 2
            ;;
        esac
    done


    # return status. (0:OK 1:Error 2:Cancel)
    return ${_result}
}

# This tool executes to take backup.
function execute() {

    local _index=0
    echo ""
    echo "===================It started to take backup by dump.====================="
    echo ""


    # change the array delimiter to 'line feed'.
    export IFS_BK=${IFS}
    export IFS=$'\n'
    for cur_command in ${global_command_list[@]}
    do

        # restore the array delimiter to 'space'.
        export IFS=${IFS_BK}

        echo "${global_command_detail_list[$_index]}"

        echo "${cur_command}"
        ${cur_command}

        # change the array delimiter to 'line feed'.
        export IFS_BK=${IFS}
        export IFS=$'\n'

        echo ""
        _index=$((${_index} + 1))
    done

    # restore the array delimiter to 'space'.
    export IFS=${IFS_BK}
    
    echo ""
    echo "===================It finished.please confirm about a result.====================="
    echo ""
    
    return 0
}

#### start point. ####

# if paramerter exists, display help.
if [ $# -ne 0 ]; then
    usage
    exit 0
fi

# execute function with sequencial term. ref: GLOBAL_FUNCTION_LIST
for func in ${GLOBAL_FUNCTION_LIST[@]}
do
    ${func}
    case  $? in
        0 )
            ;;
        1 )
            echo "Error: process has stopped. --cause: Exception occurred"
            exit 1
            ;;
        2 )
            echo "Cancel has accomplished."
            exit 2
            ;;
        *)
            echo "Error: process has stopped. --cause: UNKNOWN Exception."
            exit 1
            ;;
    esac
done

