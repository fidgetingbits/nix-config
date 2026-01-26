#!/usr/bin/env bash

IFS=''
total=0
dir=.
while read -r f; do
    # Sometimes we get .flac decoding errors
    d=$(soxi -D "$f")
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "$d s. in $f"
        echo "$total + $d"
        new=$(echo "$total + $d" | bc)
        if [ -z "$new" ]; then
            echo Calculation error
        else
            total=$new
        fi
    fi
done < <(find "$dir" -iname "*.flac")

echo "Total : $total seconds"
