#!/bin/bash



echo -e "Minux build host requirements check log:" > requirements-check-log.txt

date                             >> requirements-check-log.txt

echo                             >> requirements-check-log.txt

echo "uname -s    = '$(uname -s)'"  >> requirements-check-log.txt
echo "uname -v    = '$(uname -v)'"  >> requirements-check-log.txt
echo "uname -n    = '$(uname -n)'"  >> requirements-check-log.txt
echo "uname -m    = '$(uname -m)'"  >> requirements-check-log.txt
echo "uname -p    = '$(uname -p)'"  >> requirements-check-log.txt

echo                             >> requirements-check-log.txt

echo "bash        = $(bash         --version | head -n1 | cut -d" " -f2-4)" >> requirements-check-log.txt
echo "wget        = $(wget         --version | head -n1)" >> requirements-check-log.txt
echo "gcc         = $(gcc          --version | head -n1)" >> requirements-check-log.txt
echo "g++         = $(g++          --version | head -n1)" >> requirements-check-log.txt
echo "make        = $(make         --version | head -n1)" >> requirements-check-log.txt
echo "bc          = $(bc           --version | head -n1)" >> requirements-check-log.txt
echo "xmlstarlet  = $(xmlstarlet   --version | head -n1)" >> requirements-check-log.txt
echo "genisoimage = $(genisoimage  --version | head -n1)" >> requirements-check-log.txt

echo >> requirements-check-log.txt

cat requirements-check-log.txt
