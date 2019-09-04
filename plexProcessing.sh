#!/usr/bin/env bash

# Sleep for a pseudorandom period (up to 10 seconds) to limit the number of instances that start at once
# $$ = process % = modulo
sleep `echo $$%10 | bc`

# useful variables and info
now="$( date +%F )"
filedirname=$(dirname "$1")
fullfilename=$(basename "$1")
extensioname="${fullfilename##*.}"
filename="${fullfilename%.*}"

logfile="/tmp/${filename}.log"

sourcefile="${filedirname}/${filename}.${extensioname}"
output="${filedirname}/${filename}.mp4"

# init log
touch "${logfile}"

if [ $? -gt 0 ]
then
  echo "FAILED TO INIT LOGFILE ${logfile}" >> /tmp/plex-encode.error
  exit 99
fi


# lock file is used to limit re-encoding to one re-encoding proc
masterlock="/tmp/.plex-encoding"
mylockfile="/tmp/.plex-encodeing.$$"
masterlog="/home/plex/plex-encoding.log"

# make sure we have HandBrakeCLI
handbrake=$( which HandBrakeCLI )

if [ -z "${handbrake}" ]
then
  echo "HandBrakeCLI NOT FOUND" >> "${logfile}"
  exit 99
fi


# touch masterlog to confirm we can update it
touch "${masterlog}"

if [ $? -gt 0 ]
then
  echo "FAILED TO TOUCH masterlog ${masterlog}" >> "${logfile}"
  exit 99
fi

# wait for other plex encoders
while [ -e "${masterlock}" ]
do
  echo "sleeping $( date )" >> "${logfile}"
  # random sleep, min 2 seconds, max 20 seconds
  sleep `echo $$%10 | bc`
  sleep `echo $$%10 | bc`
done

# grab lockfile
if [ ! -e ${masterlock} ]
then
  echo "grabbing lockfile $( date )" >> "${loglife}"
  ln -s ${mylockfile} ${masterlock}
fi

# update logfile
if [ -e "${logfile}" ]
then
  echo "filedirname: ${filedirname}" >> "${logfile}"
  echo "fullfilename: ${fullfilename}" >> "${logfile}"
  echo "extensioname: ${extensioname}" >> "${logfile}"
  echo "filename: ${filename}" >> "${logfile}"
  echo "sourcfile: ${sourcefile}"
  echo "output: ${output}"
else
  echo "FAILED TO UPDATE LOGFILE ${logfile}" >> /tmp/plex-encode.error
  exit 99
fi

# update master log
echo "-------------------------------------------------------------------------------" >> ${masterlog}
echo "Starting transcoding of ${fullfilename} at $( date +%F )" >> ${masterlog}
echo "transcoding logfile is ${logfile}" >> ${masterlog}

# start time for encoding
starttime="$( date +%s )"

# encoding options
options="-f mp4 -e x264 --x264-preset veryfast --x264-profile high --x264-tune film -q 30 -E copy -s 1 --normalize-mix --large-file --decomb -O"

echo "encoding options are: $options" >> "${logfile}"

# use handbrake to transcode into mp4
nice -n 10 HandBrakeCLI $options -i "${sourcefile}" -o "${output}" >> "${logfile}" 2>&1

# make sure the output file exists and is non-zero
if [ -s "${output}" ]
then
  echo "Output exists and is non-zero" >> "${logfile}"
  echo "Removing orginal file ${sourcefile}" >> "${logfile}"
  rm -v "${sourcefile}"
fi

# handbrake doesn't have useful exit codes
# ref: https://stackoverflow.com/questions/10092609/is-there-a-good-way-to-tell-if-handbrakecli-actually-encoded-anything
# ref: https://forum.handbrake.fr/viewtopic.php?f=12&t=18559&p=85529&hilit=return+code#p85529
# if handbrake has a clean exit, then remove source file
#if [ $? -gt 0 ]
#then
#  echo "Removing orginal file ${sourcefile}" >> "${logfile}"
#  rm -v "${sourcefile}" 
#else
#  echo "Non-clean exit detected. moving ${sourcefile}" >> "${logfile}"
#  mkdir -p /tmp/plex && mv "${sourcefile}" /tmp/plex/
#fi

ls -lrth "${filedirname}" >> "${logfile}"

# update our log files
endtime=$( date +%s )
timediff=`expr $endtime - $starttime`
echo "Complete, ran for: $timediff seconds $1" >> "${logfile}"

echo "Finished transcoding of ${fullfilename} at $( date +%F )" >> ${masterlog}
echo "-------------------------------------------------------------------------------" >> ${masterlog}
echo "" >> ${masterlog}

# remove our lock
rm -f ${masterlock}

exit 0

