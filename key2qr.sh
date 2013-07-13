#!/bin/bash
hash gpg 2>&- || { echo >&2 "I require gpg but it's not installed.  Aborting."; exit 1; }
hash qrencode 2>&- || { echo >&2 "I require qrencode but it's not installed.  Aborting."; exit 1; }
hash split 2>&- || { echo >&2 "I require split but it's not installed.  Aborting."; exit 1; }
hash shred 2>&- || { echo >&2 "I require shred but it's not installed.  Aborting."; exit 1; }
hash vips 2>&- || { echo >&2 "I require vips but it's not installed. Aborting."; exit 1; }
hash convert 2>&- || { echo >&2 "I require convert but it's not installed. Aborting."; exit 1; }
hash bc 2>&- || { echo >&2 "I require bc but it's not installed. Aborting."; exit 1; }
tmpdir=$(mktemp -dp .)
cd $tmpdir
if [ -z $1 ]; then
    echo "Usage: $0 [public|private] <keyname>"
    exit 1
fi
if [ "$1" = "public" ]; then
    pubpriv="public"
else
    pubpriv="secret"
fi
if [ ! -z $2 ]; then
    keynam=$2
else
    uids=$(gpg --list-$pubpriv-keys | grep uid | sed s/uid// | sed 's/^[ \t]*//')
    gpg --list-$pubpriv-keys | grep uid | sed s/uid// | sed 's/^[ \t]*//'
    tabcomp=$(echo $uids | sed "s/.*<//;s/>.*//" | tr '\n' ' ')
    echo
    echo -ne "Please choose a key: "
    read -e keynam
fi
if [ "$pubpriv" = "secret" ]; then
    seckey="-secret-key"
fi
gpg -a --export$seckey $keynam > key 2>/dev/null
if [ ! -s key ]; then
    echo "Incorrect key provied. Aborting"
    rm key
    exit 1
fi
if [ $(wc -c key | cut -d' ' -f1) -gt 169000 ]; then 
    echo "Key too big. Aborting"
    rm key
    exit 1
fi
split -b 250 key
for i in x??; do qrencode -v 4 -o $i.png -- "$(cat $i)"; done
rm x??
totimg=$(ls -1 x??.png | wc -l)
alphabet=({a..z}{a..z})
if [ ! $(echo $totimg%2 | bc) -eq 0 ]; then
    convert -size 195x195 xc:white x${alphabet[$(($totimg))]}.png
fi
IFS=$(echo -en "\n\b")
for i in $(identify *.png | grep -v 195x195); do
    filename=$(echo "$i" | sed "s/\[.*//")
    convert $filename -bordercolor white -border 6 $filename
done
i=0
while [ $i -lt 676 ]; do
    vips im_lrjoin x${alphabet[$i]}.png x${alphabet[$(($i+1))]}.png ${alphabet[$i]}${alphabet[$(($i+1))]}.png 2>/dev/null
    i=$(echo $i+2 | bc -l)
done
shred -u key x??.png
totimgp=$(ls -1 ????.png | wc -l)
if [ ! $(echo $totimgp%4 | bc) -eq 0 ]; then
    convert -size 390x195 xc:white ${alphabet[$(($totimg))]}${alphabet[$(($totimg+1))]}.png
fi
i=0
while [ $i -lt 676 ]; do
     vips im_lrjoin ${alphabet[$i]}${alphabet[$(($i+1))]}.png ${alphabet[$(($i+2))]}${alphabet[$(($i+3))]}.png ${alphabet[$i]}${alphabet[$(($i+1))]}${alphabet[$(($i+2))]}${alphabet[$(($i+3))]}.png 2>/dev/null
    i=$(echo $i+4|bc -l)
done
shred -u ????.png
imgs=($(ls -1 ????????.png | sort | tr '\n' ' '))
totimgq=$(ls -1 ????????.png | wc -l)
i=0
if [ ! $(echo $totimgq%8 | bc) -eq 0 ]; then
    botrow=1
    convert -size 780x195 xc:white ${alphabet[$(($totimg-1))]}${alphabet[$(($totimg))]}${alphabet[$(($totimg+1))]}${alphabet[$(($totimg+2))]}.png
fi
while [ $(ls -1 *.png|wc -l) -gt 1 ]; do
    files=($(ls -1 *.png ))
    numfiles=${#files[@]}
    i=0
    while [ $i -lt $numfiles ]; do
        vips im_tbjoin ${files[$i]} ${files[$(($i+1))]} $(echo ${files[$i]}${files[$(($i+1))]} | sed s/.png//)
        shred -u ${files[$i]} ${files[$(($i+1))]}
        i=$(echo $i+2|bc)
    done
done
if [ -n botrow ]; then
    convert *.png -gravity South -chop 0x195 out.png
fi
mv out.png ${keynam}_${pubpriv}.png
mv ${keynam}_${pubpriv}.png ../
cd ..
rm -rf $tmpdir
