#!/usr/bin/env sh
# https://github.com/takeiteasy/tools
# Description: MusixMatch API scraper
# Requires: jq (https://stedolan.github.io/jq/) and curl
#
# Version 2, December 2004
#
# Copyright (C) 2022 George Watson [gigolo@hotmail.co.uk]
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
# DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE TERMS AND CONDITIONS FOR
# COPYING, DISTRIBUTION AND MODIFICATION
#
# 0. You just DO WHAT THE FUCK YOU WANT TO.

APIKEY= ...
APIURL=http://api.musixmatch.com/ws/1.1
SHOWINFO=0

BASE=$APIURL/track.search?apikey=$APIKEY
while getopts ":s:a:l:t:v" opt; do
	case $opt in
		s)
			BASE=$(echo $BASE\&q_track=$OPTARG)
			;;
		a)
			BASE=$(echo $BASE\&q_artist=$OPTARG)
			;;
		l)
			BASE=$(echo $BASE\&q_lyrics=$OPTARG)
			;;
		t)
			BASE=$(echo $BASE\&q_track_artist=$OPTARG)
			;;
		v)
			SHOWINFO=1
			;;
		\?)
			echo "ERROR! Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "ERROR! Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done
BASE=$(echo $BASE\&page_size=3&page=1&s_track_rating=desc)

JSON=$(curl -sS "$BASE")
STATUS=$(echo $JSON | jq ".message.header.status_code")
if [ "$STATUS" -ne "200" ]; then
	echo "ERROR! $STATUS status code"
	exit 1
fi

if [ $SHOWINFO -eq 1 ]; then
	AJSON=$(curl -sS "$APIURL/album.get?apikey=$APIKEY&album_id=$(echo $JSON | jq -r ".message.body.track_list[0].track.album_id")")
	ASTATUS=$(echo $AJSON | jq ".message.header.status_code")
	if [ "$ASTATUS" -ne "200" ]; then
		echo "ERROR! $ASTATUS status code"
		exit 1
	fi

	COVER_B64=$(curl -sS "$(echo $AJSON | jq -r ".message.body.album.album_coverart_100x100")" | base64)

	echo -e "\e]1337;File=inline=1:$COVER_B64\a"
	printf "\n"
	printf "%s: " $(echo $JSON | jq -r ".message.body.track_list[0].track.artist_name")
	echo $JSON | jq -r ".message.body.track_list[0].track.track_name"
	echo $JSON | jq -r ".message.body.track_list[0].track.album_name"
	printf "\n"
fi

LJSON=$(curl -sS "$APIURL/track.lyrics.get?apikey=$APIKEY&track_id=$(echo $JSON | jq -r ".message.body.track_list[0].track.track_id")")
LSTATUS=$(echo $LJSON | jq ".message.header.status_code")
if [ "$LSTATUS" -ne "200" ]; then
	echo "ERROR! $LSTATUS status code"
	exit 1
fi

echo $LJSON | jq -r ".message.body.lyrics.lyrics_body" | head -n -4
