#!/bin/bash

for i in 5901 5902 5903; do 
    vncviewer 127.0.0.1:${i}& 
done 