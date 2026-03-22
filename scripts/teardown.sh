#!/usr/bin/env bash
tmux kill-session -t "research-group" 2>/dev/null && echo "Session killed" || echo "No session found"
