#!/bin/bash
for RLOG in `find . -name "*.rlog"|sort -n`; do echo "=========$RLOG========"; tail -3 $RLOG; done
