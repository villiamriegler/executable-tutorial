# Summary

You have learned to create simple experiments in Chaos Mesh, to measure what users experience while they run, and to diagnose issues that are hard to spot any other way: a pod that comes back but caused downtime, a missing timeout that took a whole service down.

A chaos experiment is different from a test. You run it against a live environment, and it does not always find a fault in your system. What it finds is the weaknesses that make your system regress when the infrastructure around it fails, and it shows you how to build the resilience to survive them.

In the DevOps cycle it lives on the operations side: you evaluate the running system by deliberately disturbing it, and what you learn goes back into the next iteration as code.
