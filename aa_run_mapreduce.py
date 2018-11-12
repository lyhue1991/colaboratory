#!/usr/bin/python2.7
# -*- coding: utf-8 -*-
from __future__ import print_function
import os,sys

###############################################################
#change the eight arguments here!!!

job_name = 'run_word_count'
input_path = '/user/liangyun/input.txt'
output_path = '/user/liangyun/word_count_output'
mapper_file = 'word_count_mapper.py'
reducer_file = 'word_count_reducer.py'
map_argv_files = '' 
reduce_argv_files = ''
other_relayed_files = ''   #files to import or other use
getmerge_file = 'word_count_output'  #file to getmerge the last output 

# if there are more than 1 map_argv_files or reduce_argv_files,
# seperate them with a blank like below
# map_argv_files = 'file1 file2 file3'

# don't change the code below!!!
################################################################

set_mapper = ('"python2.7 %s %s "' % (mapper_file,map_argv_files)) \
             if mapper_file else 'cat '
set_reducer = ('"python2.7 %s %s "' % (reducer_file,reduce_argv_files)) \
             if reducer_file else 'NONE '
files = [mapper_file,reducer_file,map_argv_files,reduce_argv_files,other_relayed_files]
set_files = ','.join(filter(lambda x:x,files)).replace(' ',',')


COMMAND_HEAD = "hadoop jar /opt/cloudera/parcels/CDH-5.3.1-1.cdh5.3.1.p0.5/lib/hadoop-mapreduce/hadoop-streaming.jar \
-libjars  /opt/cloudera/parcels/CDH-5.3.1-1.cdh5.3.1.p0.5/jars/hive-exec-0.13.1-cdh5.3.1.jar "

command = 'hadoop fs -rm -r ' + output_path
os.system(command)

print('**********************************************************\n')

command =  COMMAND_HEAD + \
        ' -files ' + set_files +\
        ' -D mapreduce.job.map.tasks=2000' +\
        ' -D mapreduce.job.map.capacity=1000' +\
        ' -D mapreduce.reduce.tasks=400' +\
        ' -D mapreduce.job.reduce.capacity=200' +\
        ' -D stream.non.zero.exit.is.failure=false' +\
        ' -D mapreduce.job.priority=VERY_HIGH' +\
        ' -D stream.num.map.output.key.fields=1' +\
        ' -D num.key.fields.for.partition=1' +\
        ' -D mapreduce.job.name=%s' % job_name +\
        ' -input ' + input_path + \
        ' -output ' + output_path + \
        ' -mapper '+ set_mapper + \
        ' -reducer '+ set_reducer + \
        ' -partitioner org.apache.hadoop.mapred.lib.KeyFieldBasedPartitioner'
print(command+'\n')
ret = os.system(command)
if ret != 0:
    print(job_name + ' mr job error!',file = sys.stderr)

lastcommand = 'hdfs dfs -getmerge '+ output_path + ' '+ getmerge_file

if getmerge_file:
    os.system(lastcommand)

#####
####
###
##
#
