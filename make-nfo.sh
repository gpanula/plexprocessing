#!/bin/bash

# usage
usage() {
  echo "Usage: $0 -x /path/to/file.xml -s /where/the/video/lives -d /write/nfo/here" 1>&2
  exit 99
}

# grab command-line switch
while getopts ":x:s:d:" o;
do
  case "${o}" in
    x)
      # name of the xml file with the info
      xmlinfo="${OPTARG}"
      ;;
    s)
      # directory where the video file lives
      vidsrc="${OPTARG}"
      ;;
    d)
      # destination directory for the nfo
      dst="${OPTARG}"
      ;;
    *)
      # catch all
      usage
      ;;
  esac
done
shift $((OPTIND-1))

[ -z $dst ] && echo "need -d (directory to write nfo file to)" && exit 99
[ -z $vidsrc ] && vidsrc="/home/mythtv/football"
[ -z $xmlinfo ] && echo "need -x (xml info file)" && exit 99
[ ! -e ${xmlinfo} ] && echo "${xmlinfo} NOT FOUND" && exit 99
[ ! -e ${vidsrc} ] && echo "${vidsrc} NOT FOUND" && exit 99

mediainfo=$( which mediainfo )

description="$( grep field ${xmlinfo} | grep description | cut -d'>' -f2 | cut -d'<' -f1 )"
subtitle="$( grep field ${xmlinfo} | grep subtitle | cut -d'>' -f2 | cut -d'<' -f1 )"
airdate="$( grep field ${xmlinfo} | grep starttime | cut -d'>' -f2 | cut -d'<' -f1 )"
basename="$( grep field ${xmlinfo} | grep basename | cut -d'>' -f2 | cut -d'<' -f1 )"
banner="$( echo $subtitle | sed 's/at /\n&\n/' | figlet -cf slant )"
nfo="$( echo $xmlinfo | awk -F/ '{ print $NF }' | sed 's:xml:nfo:')"
target="${dst}/${nfo}"

if [ ! -z "${description}" ]
then
  # word-wrap the description
  echo "Description: $description" > /tmp/descr.$$
  wrapped=$( fold -w 70 -s /tmp/descr.$$ )
  rm -f /tmp/descr.$$
fi

if [ ! -e "${vidsrc}/${basename}" ]
then
  echo "${vidsrc}/${basename} NOT FOUND"
  echo "Not generating video/audio info"
else
  if [ ! -z $mediainfo ]
  then
    videoinfo="$( $mediainfo --Output=JSON $vidsrc/$basename | jq '.media.track[] | select(."@type"=="Video") | {FrameRate,FrameRate_Mode,Width,Height,DisplayAspectRatio,Encoded_Library}' )"
    audioinfo="$( $mediainfo --Output=JSON $vidsrc/$basename | jq '.media.track[] | select(."@type"=="Audio") | {Format,CodecID,BitRate,BitRate_Mode,Language,Channels,ChannelPositions}' )"
    ccinfo="$( $mediainfo --Output=JSON $vidsrc/$basename | jq '.media.track[] | select(."@type"=="Text") | {Format,CodecID,Language,Forced}' )"

    cat <<EOF >> /tmp/vfo.$$

Video info:
$videoinfo

Audio info:
$audioinfo

Closed Caption info:
$ccinfo

EOF
  fi
fi

[ -e $target ] && rm -f $target

cat <<EOF >> $target

$banner

Title......: $subtitle
Gameday....: $airdate
Source.....: OTA broadcast with commericals included
$( [ ! -z "${wrapped}" ] && echo "${wrapped}" && echo "" && echo "" )
$( [ -e /tmp/vfo.$$ ] && cat /tmp/vfo.$$ && rm -f /tmp/vfo.$$ )

EOF

