#!/usr/bin/env sh
# Description: Github gist scraper
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

function pages {
  echo "($1 + $2 - 1) / $2" | bc
}

for user in $@; do
	path="$(pwd)/$(echo "$user")"
	if test ! -d "$path"; then
		mkdir "$path"
	fi
	npages=$(pages $(curl -s "https://api.github.com/users/$user" | jq -r '.public_gists') 30)
	for (( i=1; i<=$npages; i++ )); do
		curl -s "https://api.github.com/users/$user/gists?page=$i" | jq -c ".[]" | while IFS='' read file; do
			path="$(pwd)/$(echo "$user")"
			nfiles=$(echo "$file" | jq -r ".files | length")
			if test $nfiles -gt 1; then
				path="$(echo "$path")/$(echo "$file" | jq -r "[.files[]] | .[0].filename" | cut -d '.' -f 1)"
				if test ! -d "$path"; then
					mkdir "$path"
				fi
			fi
			echo "$file" | jq -r ".files[].raw_url" | while read -r url; do
				curl "$url" -o "$(echo "$path")/$(echo "$url" | rev | cut -d '/' -f 1 | rev)"
			done
		done
	done
done
