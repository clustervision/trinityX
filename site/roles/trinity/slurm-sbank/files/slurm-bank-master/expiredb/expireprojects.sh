#!/bin/sh

projects=$(recsel -C -R project -t project -e "enddate << '`date -I`'" projects.rec)

for i in $projects
do 
	sbank project expire -a $i -c $(sbank cluster list) 
done
