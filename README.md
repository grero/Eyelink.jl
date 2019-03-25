# Eyelink

[![Build Status](https://travis-ci.org/grero/Eyelink.jl.svg?branch=master)](https://travis-ci.org/grero/Eyelink.jl)
[![Coverage Status](https://coveralls.io/repos/github/grero/Eyelink.jl/badge.svg?branch=master)](https://coveralls.io/github/grero/Eyelink.jl?branch=master)
## Introduction
Open up an EDF file, loading both events and continuos data:

```julia
eyelinkdata = Eyelink.load("w7_10_2.edf")
```

Since an EDF file contains a lot of data, and one might not be interested in all that data for every analysis, there are convenience functions for getting certain types of data. For instance, to get just the calibrated gaze positions, one can do the following

```julia
gazex, gazey, gtime = Eyelink.getgazepos("w7_10_2.edf")
```
