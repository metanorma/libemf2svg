#!/bin/sh
# $1  -- folder with emf files
# $2  -- folder with refeernce svg files
# $3  -- tmp folder  for conversion results

CMD="`find . -type f -name emf2svg-conv`"
BASEDIR="$(dirname $0)"
mkdir -p $BASEDIR/$3

for emf in `find $BASEDIR/$1 -type f -name "*.emf" | sort`
do 
 nm="`basename $emf`.svg"
 svg="$BASEDIR/$3/$nm"
 ref="$BASEDIR/$2/$nm"
 echo -n "Checking $emf..."
 $CMD --input=$emf --output=$svg
 cmp -s "$svg" "$ref"
 if [ $? != 0 ];then
    echo "error"
    exit 1
 else
    echo "OK"
 fi
done
exit 0
