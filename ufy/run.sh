#!/bin/sh
luatex --lua=pre_init.lua --shell-escape --fmt=plain --output-format=pdf $1