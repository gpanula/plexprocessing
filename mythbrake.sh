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
audio_track="$( $mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Audio") | select(.Language=="en") | ."@typeorder"' | head -n 1 )"

# info
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="General")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Video")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Audio") | select(.Language=="en")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Text") | select(.Format=="EIA-608")' >> $log

# handbrake options
# ref: https://handbrake.fr/docs/en/latest/cli/command-line-reference.html
# ref: https://handbrake.fr/docs/en/latest/technical/official-presets.html
if [ ! -z ${cc_track} ]
then
  options="-a ${audio_track} -E copy:ac3 --normalize-mix --large-file --decomb -O -s ${cc_track}"
else
  options="-a ${audio_track} -E copy:ac3 --normalize-mix --large-file --decomb -O"
fi

# ref: https://handbrake.fr/docs/en/latest/technical/official-presets.html
preset="Very Fast 1080p30"

# using flatpak, so we can use the latest version of handbrake
flatpak="$( which flatpak )"
handbrakecli="$flatpak --filesystem=/home/mythtv run fr.handbrake.HandBrakeCLI"

# transcode the file
echo $( date ) >> $log
nice -n 10 $handbrakecli -Z "$preset" $options -i "${input}" -o "${output}" >> "${log}" 2>&1
echo $( date ) >> $log

exit 0

