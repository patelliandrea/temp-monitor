#!/usr/bin/python

N_MOTES = 4
DBG_CHANNELS = "default error"
SIM_TIME = 1000
TOPO_FILE = "linkgain.out"
#NOISE_FILE = "/opt/tinyos-2.1.0/tos/lib/tossim/noise/casino-lab.txt"
NOISE_FILE = "/Users/patelliandrea/Desktop/tinyos-2.x-master/tos/lib/tossim/noise/meyer-heavy.txt"

from TOSSIM import *
from tinyos.tossim.TossimApp import *
from random import *
import sys

t = Tossim([])
r = t.radio()

t.randomSeed(1)

for channel in DBG_CHANNELS.split():
	t.addChannel(channel, sys.stdout)


#a dd gain
f = open(TOPO_FILE, "r")
lines = f.readlines()

for line in lines:
	s = line.split()
	if (len(s) > 0):
		if s[0] == "gain":
			r.add(int(s[1]), int(s[2]), float(s[3]))
		elif s[0] == "noise":
			r.setNoise(int(s[1]), float(s[2]), float(s[3]))

# add noise
noise = open(NOISE_FILE, "r")
lines = noise.readlines()
for line in lines:
	str = line.strip()
	if (str != ""):
		val = int(float(str))
		for i in range(0, N_MOTES):
			t.getNode(i).addNoiseTraceReading(val)


# boot each node
for i in range (0, N_MOTES):
	time=i * t.ticksPerSecond() / 100
	m=t.getNode(i)
	m.bootAtTime(time)
	m.createNoiseModel()
	print "Booting Node", i

time = t.time()
lastTime = -1
while (time + SIM_TIME * t.ticksPerSecond() > t.time()):
	timeTemp = int(t.time()/(t.ticksPerSecond()*10))
	if( timeTemp > lastTime ): 
		lastTime = timeTemp
		print "---------------------------------------------------------------------"
	t.runNextEvent()