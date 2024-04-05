print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;
import random;

from TOSSIM import *;

t = Tossim([]);

# load topology and noise model
topofile="topology.txt";
modelfile="meyer-heavy.txt"; 

print "Initializing mac...";
mac = t.mac();
print "Initializing radio...";
radio=t.radio();
print "Using topology:",topofile;
print "Using noise:",modelfile;
print "Initializing simulator...";
t.init();

simulation_outfile = "simulation.txt";
print "Saving sensors simulation output to:", simulation_outfile;
simulation_out = open(simulation_outfile, "w");

out = open(simulation_outfile, "w");
#out = sys.stdout;

#Add debug channel
print "Activate messages on channel boot"
t.addChannel("boot",out);
print "Activate messages on channel node"
t.addChannel("node",out);
print "Activate messages on channel debug"
t.addChannel("debug",out);
print "Activate messages on channel error"
t.addChannel("error",out);

#set the number of nodes
numNodes = 9;

nodes = [];

#node creation and boot
for x in range(1,numNodes+1):
        nodes.insert(x-1,t.getNode(x));
        boot_time = random.randint(0,30) * t.ticksPerSecond();
        nodes[x-1].bootAtTime(boot_time);
        print >>out,"Creating node ",x,"...Will boot at ",boot_time/t.ticksPerSecond(), "[sec]";  



print >>out,"Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))

#Channel model creation
print >>out,"Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print >>out,"Reading noise model data file:", modelfile;
print >>out,"Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, numNodes+1):
            t.getNode(i).addNoiseTraceReading(val)
print >>out,"Done!";

#create noise model
for i in range(1, numNodes+1):
    t.getNode(i).createNoiseModel()

print >>out,"[TOSSIM] Start simulation with TOSSIM! \n\n\n";

for i in range(0,500000):
        t.runNextEvent()
	
print >>out, "\n\n\n[TOSSIM]Simulation finished!";


