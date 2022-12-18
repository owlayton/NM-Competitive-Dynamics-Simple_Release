# NM-Competitive-Dynamics-Simple_Release
CD model simulated in Ali, Decker &amp; Layton (Journal of Vision)

To get started, (TDB)[download the Switch Experiment optic flow dataset]. Unzip data.zip to the base project directory, replacing the data subdirectory.

## Running CD model on Switch Experiment dataset

Run `runSwitchExp.m`.

## Running CD model on single optic flow stimulus

Run `runCDModel.m`, passing in the optic flow sample number. For example `runCDModel(1)` to run sample 1. To plot MSTd activity during simulation set "mstdAct" parameter within "plot" section of "default.json" to `true`.
