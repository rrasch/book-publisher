#!/bin/bash

source /opt/rh/rh-python36/enable

exec `dirname "$0"`/shrink-aco-pdf.py "$@"

