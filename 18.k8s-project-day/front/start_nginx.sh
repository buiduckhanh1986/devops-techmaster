#!/usr/bin/env bash
for file in /usr/share/nginx/html/js/app.*.js;
do
 if [ ! -f $file.tmp.js ]; then
   cp $file $file.tmp.js
 fi
 envsubst '$BASE_URL' < $file.tmp.js > $file
done
nginx -g 'daemon off;'