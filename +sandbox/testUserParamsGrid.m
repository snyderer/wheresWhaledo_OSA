close all force;
fig = uifigure;

panelHandle = uipanel(fig,"Title","User settings", "Position", [10, 10, 400, 200])

detectorObj = detectors.humpback.humpback_pamdata;

G = utils.buildUserParamsGrid(panelHandle, detectorObj)

%%

