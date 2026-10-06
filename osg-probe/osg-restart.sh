#!/bin/bash
# usage: osg-restart.sh <tree> <log>  — stop the osd-heavy group serving <tree>, start it again (instance from 20-29)
TREE=$1; LOG=$2
P=$(ps -eo pid,args | grep "[ ]$TREE/tools/osd-heavy.sh" | awk '{print $1}' | head -1)
[ -n "$P" ] && kill -TERM -$P
sleep 3
cd $TREE && export PATH=/home/alice/.nvm/versions/node/v22.23.3/bin:$PATH && setsid nohup env OSD_HEAVY_RANGE=20-29 OSD_HEAVY_SLOTS=3 OSD_ADT_ONE_RUNTIME=1 OSD_WARM=1 OSD_WARM_QUIET_MS=86400000 \
  OSD_DATASET_READ=$HOME/.config/pia OSD_DATASET_WRITE=$HOME/dev/pia/.state:$HOME/.config/pia OSD_DATASET_HOME=$HOME/.config/pia \
  bash -c "exec tools/osd-heavy.sh env OSD_BIND=0.0.0.0 npm start > $LOG 2>&1" > /dev/null 2>&1 &
