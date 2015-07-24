#!/bin/bash
git add ./* lib/GEMMA/* bin/* etc/*
git commit --amend -m WIP
git pull --no-edit
git push
