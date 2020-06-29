#!/bin/bash

#
# Implementation of BASH + NCAT chat server 
# 
# Author: Anastas Dancha <anapsix@random.io>
# Contact: anapsix@random.io
#

#debug="true"

pid=$$
home_dir=/tmp/chat
user_dir=/tmp/chat/users
room_dir=/tmp/chat/rooms

# check if ncat is installed
# if so, try starting up the chat server
[ ! -e "$(which ncat)" ] && (echo "ncat is not installed.. cannot continue"; exit 1)

# check if a process already running
if [ "$(ps -ef | grep -v grep | grep -c "ncat.*$(basename $0)")" -lt "1" ]
then
  echo "starting Chat server in 3 seconds"
  for i in {3..0}; do echo -ne "${i}.. "; sleep 1; done
  [ ! -e "$user_dir" ] && mkdir -p $user_dir
  while true; do ncat -m 10 -v -k -l -p 8080 -c $0; done
else
  [[ ! $(tty) ]] && exit 1  # if running under ncat and called from TTY -> exit
fi

# welcome on initial connection
welcome() {
  echo "# Welcome to the NET-TALK"
  echo "# chat server based on NETCAT & BASH"
}

# clanup left over tails running as root
cleanup() {
  ps -ef | grep "\s1\s.*tail.*$home_dir" | grep -v $pid | awk '$3~1 {print $2}' | xargs -i kill {}
}

# read input (256 char max)
read_input() {
  read -n 256 command
  echo $command
  return
} 

# login
lin() {
  username=$1
  if [ -z "$username" ] # check if username is passed
  then
    echo "ERROR no username specified"
    return 1
  elif [ -e "$user_dir/$username" ] # check if username is taken
  then
    echo "ERROR this username is already taken"
    username="" # reset username variable
    return 1
  fi
  # cleanup "room logins" when login in
  find $room_dir -type f -name "$username" -delete
  # login and start accepting messages
  touch $user_dir/$username
  echo "OK"
  tail --pid $pid -q -f $user_dir/$username&
  return
}

# logout
lout() {
  username=$1
  if [ -z "$username" ] # check if username is passed
  then
    echo "ERROR you are not logged in"
    return 1
  else
    # cleanup when loggin out
    rm -f $user_dir/$username
    rm -f $room_dir/*/$username
    username=""
    echo "OK"
    return
  fi
}

# join/create rooms
join() {
  room=$1
  if [ -z "$username" ] # check if logged in
  then
    echo "ERROR you are not logged in"
    return 1
  elif [ -z "$room" ] # check if roomname is specified
  then
    echo "ERROR no room name specified, room name must begin with #"
    return 1
  elif [ ! -e "$room_dir/$room" ] # create a room if it doesn't exist
  then
    mkdir -p $room_dir/$room
  fi
  # login user to the room by creating a symlink to the message file :P
  ln -s $user_dir/$username $room_dir/$room/$username
  echo "OK"
  return
}

# leave rooms
part() {
  room=$1
  if [ -z "$username" ] # check if logged in
  then
    echo "ERROR you are not logged in"
    return 1
  elif [ ! -e "$room_dir/$room/$username" ] # see if logged into the room
  then
    echo "ERROR cannot leave room which never joined"
    return 1
  fi
  rm -f $room_dir/$room/$username # logout from the room
  echo "OK"
  return
}

msg() {
  if [ -z "$username" ]   # check if user is logged-in
  then
    echo "ERROR you are not logged in"
    return 1
  fi
  if [[ "${1::1}" == "#" ]]   # check where message is sent
  then                        # if destination begins with "#"
    room=$1                   # delivering to the room
    if [[ ! $(find $room_dir/$room -type f -follow) ]] # check is room exists
    then
      echo "ERROR room does not exist"
      return 1
    fi
    shift   # fist argument is destination
    message=$@    # everything else is a part of the message
    for i in $(ls $room_dir/$room/);  # deliver the message to everyone in the room
    do                                # add "grep -v $username" if want to skip self
      echo "GOTROOMMSG $username $room $message" >> $room_dir/$room/${i}
    done
  else    # if first arg does not start with #
    recip=$1    # destination must be user
    if [ ! -e "$user_dir/$recip" ]
    then
      echo "ERROR user $recip is not logged in"
      return 1
    else
      shift
      message=$@
      echo "GOTUSERMSG $username $message" >> $user_dir/$recip
      return
    fi
  fi
}

# do something useful
do_something() {
  cleanup
  command="$*"
  niy="is not implemented yet.."
  case "$command" in
  LOGIN*)
    username=${command#LOGIN }
    username=$(expr match "$username" '\([a-zA-Z0-9]*\)')
    lin $username
  ;;
  LOGOUT*)
    lout $username
    exit 0
  ;;
  JOIN*)
    room=${command#JOIN }
    room=$(expr match "$room" '\(#[a-zA-Z0-9]*\)')
    join $room
  ;;
  PART*)
    room=${command#PART }
    room=$(expr match "$room" '\(#[a-zA-Z0-9]*\)')
    part $room
  ;;
  MSG*)
    message_string=${command#MSG }
    message_string=$(expr match "$message_string" '\([#a-zA-Z0-9]*\s.*\)')
    msg $message_string
  ;;
  *)
    echo "ERROR command is not recognized; available commands are LOGIN <username>, LOGOUT, JOIN <#room>, PART <#room>, MSG <username|#room> <message>"
    ;;
  esac
}

# Run Forest, run!
welcome
while true; do
  command=$(read_input)
  [ ! -z "$debug" ] && echo "debug: $command"
  do_something "$command"
done

#
# NOTE: test if string starts with # like so:
# [[ "${room::1}" == "#" ]] && echo yes || echo no
#
# EOF
