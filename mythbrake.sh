#!/bin/sh

# list myth job variables
# http://www.havetheknowhow.com/Install-the-software/MythTV-user-job-arguments.html

DIR=$1
FILE=$2

OUTFILE="$( echo $FILE | cut -d'.' -f1 | sed 's/.*/&.mp4/' )"
LOGFILE="$( echo $FILE | cut -d'.' -f1 | sed 's/.*/&.log/' )"

input="${DIR}/${FILE}"
output="${DIR}/${OUTFILE}"
log="${DIR}/${LOGFILE}"

if [ ! -e $input ]
then
  echo "!!! $input NOT FOUND !!!" | logger
  exit 99
fi

mediainfo="$( which mediainfo)"

# grab first 608 formatted CC track
cc_track="$( $mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Text") | select(.Format=="EIA-608") | ."@typeorder"' | head -n 1 )"

# grab first english audio track
audio_track="$( $mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Text") | select(.Language=="en") | ."@typeorder"' | head -n 1 )"

# handbrake options
# ref: https://handbrake.fr/docs/en/latest/cli/command-line-reference.html
options="-f mp4 -e x264 --x264-preset veryfast --x264-profile high --x264-tune film -q 30 -a ${audio_track} -E copy:ac3 --normalize-mix --large-file --decomb -O -s ${cc_track}"

# transcode the file
echo $( date ) >> $log
nice -n 10 HandBrakeCLI $options -i "${input}" -o "${output}" >> "${log}" 2>&1
echo $( date ) >> $log

exit 0

