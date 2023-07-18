#!/usr/bin/python3

import yaml
import sys

data = None
controller_ip = ""

with open(sys.argv[1]) as f:
	data = yaml.safe_load(f)

fp = open("hosts", "w")

role_list = ["controller", "compute", "storage"]

for role in role_list:
   fp.write("\n[" + str(role) + "]\n")
   for n in data["nodes"]:
      for r in n["roles"]:
         if r == role:   
            fp.write(n["oam_ip"] + "\n")
	

for n in data["nodes"]:

   fp.write("\n[" + str(n["name"]).replace("-", "_") + "]\n")
   fp.write(n["oam_ip"] + "\n")

fp.close()
