#bin/bash

CURRENT=$(date "+%Y-%m-%d %H:%M:%S")
git commit -am "$(date "+%Y-%m-%d %H:%M:%S")" && git push note master
