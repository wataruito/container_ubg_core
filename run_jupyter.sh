#!/bin/sh
jupyter notebook --ip=0.0.0.0 --no-browser --notebook-dir=$JUPYTER_START --NotebookApp.token=$JUPYTER_TOKEN