#!/bin/sh

# list myth job variables
# http://www.havetheknowhow.com/Install-the-software/MythTV-user-job-arguments.html

DIR=$1
FILE=$2
CHANID=$3

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

framerate="$( $mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Video") | .FrameRate' | cut -c1-5 )"

echo "" >> $log
echo "Version: 2019-11-30 23:31" >> $log
echo "input: $input" >> $log
echo "output: $output" >> $log
echo "chanid: $CHANID" >> $log
echo "" >> $log

# info
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="General")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Video")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Audio") | select(.Language=="en")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Text") | select(.Format=="EIA-608")' >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Video") | .ScanType'  >> $log
$mediainfo --Output=JSON $input | jq -r '.media.track[] | select(."@type"=="Video") | .FrameRate' | cut -c1-5 >> $log


# set cc option if we found a cc track
if [ ! -z ${cc_track} ]
then
  cc="-s ${cc_track}"
else
  cc=""
fi

# handbrake options
# ref: https://handbrake.fr/docs/en/latest/cli/command-line-reference.html
# ref: https://handbrake.fr/docs/en/latest/technical/official-presets.html

# * CBS & NBC broadcasts in 1080i30, FOX in 720p60
# * "Roku 720p30 Surround" is a preset the handles both formats; good picture and **reduces** the file size
preset="Roku 720p30 Surround"

static_handbrake_options='-f mp4 -e x264 -q 26 -E copy:ac3 --normalize-mix --large-file -O --vfr'
handbrake_options="${static_handbrake_options} -a ${audio_track} ${cc}"

# using flatpak, so we can use the latest version of handbrake
flatpak="$( which flatpak )"
handbrakecli="$flatpak --filesystem=/home/mythtv run fr.handbrake.HandBrakeCLI"

echo ""
echo $handbrakecli -Z "${preset}" $handbrake_options -i "${input}" -o "${output}" >> "${log}" 2>&1
echo ""

# transcode the file
echo "Transcoding started at $( date )" >> $log
#script -a -c 'nice -n 10 $handbrakecli $handbrake_options -i "${input}" -o "${output}" 2>&1' ${log}
nice -n 10 $handbrakecli -Z "${preset}" $handbrake_options -i "${input}" -o "${output}" >> ${log} 2>&1
echo "Transcoding completed at: $( date )" >> $log

if [ -s ${output} ]
then
  # the output exists and is non-zero in size
  # delete the input file
  echo "deleting ${input}" >> $log
  rm -f ${input}
fi

announce="udp://172.27.228.2:6969/announce"
torrentout="/home/mythtv/torrent/$( echo $OUTFILE | sed 's:mp4:torrent:' )"
mktorrent=$(which mktorrent)

echo "" >> $log
echo "Now creating torrent file for $output" >> $log

if [ -z "${mktorrent}" ]
then
  echo "mktorrent NOT FOUND" >> $log
else
  echo "mktorrent -v -a $announce -n $OUTFILE -l 22 -o $torrentout $output" >> $log
  $mktorrent -v -a $announce -n $OUTFILE -l 22 -o $torrentout $output
fi

echo "" >> $log
echo "Now attempting to update mythconverg" >> $log
echo "" >> $log

if [ -z "${CHANID}" ]
then
  echo "Missing CHANID, skipping the updating of mythconverg"
  exit 0
else
  # update mythconverg
  mysql=$( which mysql )
  mysql_options="-u mythtv -pmythtv -s -r -N -D mythconverg"
  subtitle_query="select subtitle from recorded where chanid=$CHANID and basename='$FILE';"
  subtitle=$( $mysql $mysql_options -e "$subtitle_query")
  
  title_query="select title from recorded where chanid=$CHANID and basename='$FILE';"
  title=$( $mysql $mysql_options -e "$title_query")
  
  trimmed_title=$( echo $title | sed 's/FOX NFL //' | sed 's/^.*Football: //' | sed 's/@/at/' )
  
  # if subtitle is empty populate it with bit from title
  # FOX seems to be the only one not populating the subtitle
  if [ ! -z "${subtitle}" ]
  then
    echo $subtitle >> "${log}"
  else
    echo subtitle is empty >> "${log}"
    echo title is $title >> "${log}"
    echo trimmed_title is $trimmed_title >> "${log}" 2>&1
    $mysql $mysql_options -e "update recorded set subtitle='$trimmed_title' where chanid=$CHANID and basename='$FILE';"
    echo updated subtitle is >> "${log}"
    $mysql $mysql_options -e "$subtitle_query" >> "${log}" 2>&1
  fi
  
  # update basename to new file
  $mysql $mysql_options -e "update recorded set basename='$OUTFILE' where chanid=$CHANID and basename='$FILE';" >> "${log}" 2>&1
  
  # update filesize
  filesize=$( ls -l $output | awk '{ print $5 }' )
  $mysql $mysql_options -e "update recorded set filesize='$filesize' where chanid=$CHANID and basename='$OUTFILE';" >> "${log}" 2>&1
  
  $mysql $mysql_options -e "select subtitle,basename,filesize from recorded where chanid=$CHANID and basename='$OUTFILE';"  >> "${log}" 2>&1
fi

exit 0

