classdef  fsolveLocalization < handle
properties
    soundSpeed = 1490;
%     {mustBeMember(Style, ["solid","dash","dot"])}
end 
methods
function defineUserParams(obj)
            % This function will be called by localizePanel to make a table
            % of parameters the user needs to set to run this detector.

            % list of required user-defined params needed for this detector
            % values are default values
            obj.userParams.PAMfileLocation.value = '';
            obj.userParams.PAMfileLocation.type = 'file';
            obj.userParams.PAMfileLocation.description = 'Location of PAM file';

            obj.userParams.filterOrder.value = 15;
            obj.userParams.filterOrder.type = 'numerical';
            obj.userParams.filterOrder.description = 'passband filter order';

            obj.userParams.rejFilterOrder.value = 6;
            obj.userParams.rejFilterOrder.type = 'numerical';
            obj.userParams.rejFilterOrder.description = 'band reject filter order';

            obj.userParams.rejFilterFreq.value = 2e3;
            obj.userParams.rejFilterFreq.type = 'numerical';
            obj.userParams.rejFilterFreq.description = 'band reject center frequency [Hz]';

            recTable = obj.wheresWhaledo.arrayPanel.receiverTable.Data;
            maxrng = max(sqrt(recTable.x_m.^2 + recTable.y_m.^2 + recTable.z_m.^2)); % estimate of maximum TDOA
            obj.userParams.maxTDOA.value = max([2*maxrng/1480, 1]);
            obj.userParams.maxTDOA.type = 'numerical';
            obj.userParams.maxTDOA.description = 'maximum allowed TDOA [s]';
        end


    function LOC = runLoc(DET, ARR)
        % LOC = fsolveLocalization(DET, ARR)
        % Iterate over each TDOA and localize using fsolve
        % DET is detection table, ARR is array table, LOC is localization table

        % idxLoc = find(DET.TDOA)
    end
end
end