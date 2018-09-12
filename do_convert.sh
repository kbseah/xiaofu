#!/bin/bash

for i in xiaofu_juan{01,02,03,04,05,06,07}.txt; do
    j=${i%.txt}
    perl ctext2html.pl -i $i -o $j.html --ctext_scan_url="https://ctext.org/library.pl?if=en&file=92728&page="
done

for i in xiaofu_juan{08,09,10,11,12,13}.txt; do
    j=${i%.txt}
    perl ctext2html.pl -i $i -o $j.html --ctext_scan_url="https://ctext.org/library.pl?if=en&file=92729&page="
done
