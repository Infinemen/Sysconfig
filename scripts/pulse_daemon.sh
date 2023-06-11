#!/bin/sh
pactl subscribe |
    while read -r output ; do
        case $output in
            *"sink "*) sigdwmblocks 4 ;;
        esac
    done
