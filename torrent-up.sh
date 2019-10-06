#!/bin/sh

# rtorrent directories
download="/home/padre/rtorrent/download"
watch="/home/padre/rtorrent/watch"

# mythtv directories
mythtorrent="/home/mythtv/torrent"
mythfootball="/home/mythtv/football"
mythdefault="/home/mythtv/default"

mktorrent=$( which mktorrent)
[ -z $mktorrent ] && echo missing mktorrent && exit 99

tracker="udp://172.27.228.2:6969/announce"

# create symlinks to file based on what is found in the myth torrent directory
# yes, there is a bug in the current mythbrake.sh script
for x in $( find $mythtorrent -type f )
do
  src="$( echo $x | sed 's:torrent:football:')"
  tgt="$( echo $x | awk -F/ '{ print $NF }')"
  torrent="$( echo $tgt | sed 's:mp4:torrent:')"

  # some older files will be in the default folder
  if [ ! -e $src ]
  then
    echo "$src missing, switching to default folder"
    src="$( echo $s | sed 's:torrent:default:')"
  fi

  # check to see if the symlink exists
  if [ ! -e $download/$tgt ]
  then
    echo "symlink $download/$tgt doesn't exist"
    ln -s $src $download/$tgt
  fi

  # check for existing torrent
  if [ ! -e $watch/$torrent ]
  then
    # create torrent
    echo "creating a torrent for $src"
    echo "$mktorrent -v -a $tracker -n $tgt -l 22 -o $watch/$torrent $src"
    $mktorrent -v -a $tracker -n $tgt -l 22 -o $watch/$torrent $src
    [ $? -gt 0 ] && echo Error creating torrent file && exit 99
    scp -P 4242 $watch/$torrent marge.kablah.com:/home/whale/rutorrent/downloads/watched/${torrent}
  fi

done
