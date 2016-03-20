#!/bin/bash

for i in xiaofu_juan*.txt; do
    j=${i%.txt}
    perl ctext2html.pl -i $i -o $j.html
done
