# author : qliu
# to be finished. expeirence python. 


import json
import argparse
import datetime
import os

def writeutclog(content):
    currenttime=datetime.datetime.utcnow()
    print("["+str(currenttime)+"],"+content)

def recursive(dir):
    files = os.listdir(dir)
    for obj in files:
            if os.path.isfile(os.path.join(dir,obj)):
                if obj.upper() == "PT1H.JSON":
                    #writeutclog ("File : "+os.path.join(dir,obj))
                    global i; i+=1
                    global nsgfilestring; nsgfilestring+=os.path.join(dir,obj)+","
            elif os.path.isdir(os.path.join(dir,obj)):
                recursive(os.path.join(dir, obj))
            else:
                writeutclog ("Not a directory or file %s" % (os.path.join(dir, obj)))

def PT1H2CSV(file):
    writeutclog  ("File : "+file)
    with open(file, 'r') as fcc_file:
        fcc_data = json.load(fcc_file)
    #print(fcc_data)    

# create parser
parser = argparse.ArgumentParser()
 
# add arguments to the parser
parser.add_argument("srcpath")
 
# parse the arguments
args = parser.parse_args()

# verify srcpath exist 
if os.path.exists(args.srcpath):
  writeutclog("Generate a list of nsgflowlogs (PT1H.JSON) under "+args.srcpath+"...")
  nsgfilestring=""
  i=0
  recursive(args.srcpath)
  #print(nsgfilestring.rstrip(',').split(','))
  for file in nsgfilestring.rstrip(',').split(','):
        PT1H2CSV(file)
  writeutclog("nsgflowlogs Total : "+str(i)+" File(s)")
 
else:
  writeutclog(args.srcpath+"does not exsit, please check")

