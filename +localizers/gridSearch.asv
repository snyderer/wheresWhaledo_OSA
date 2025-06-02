classdef gridSearch < handle
    properties
        userParams
        internalParams
        wheresWhaledo

        DET             % detection table (from detection grid)
        MOD             % model
        LOC             % localization table
        
    end

    methods
        function obj = gridSearch(wheresWhaledo)
            obj.wheresWhaledo = wheresWhaledo;
            obj.MOD = [];
            obj.LOC = [];
            obj.DET = obj.wheresWhaledo.detectorPanel.DET;
        end
        function defineUserParams(obj)
            % This function will be called by localizePanel to make a table
            % of parameters the user needs to set to run this localizer.

            obj.userParams.xmin_m.value = -4000;
            obj.userParams.xmin_m.type = 'numerical';
            obj.userParams.xmin_m.description = 'minimum x value [m]';

            obj.userParams.xmax_m.value = 4000;
            obj.userParams.xmax_m.type = 'numerical';
            obj.userParams.xmax_m.description = 'maximum x value [m]';

            obj.userParams.xSpacing_m.value = 50;
            obj.userParams.xSpacing_m.type = 'numerical';
            obj.userParams.xSpacing_m.description = 'x grid spacing [m]';

            obj.userParams.ymin_m.value = -4000;
            obj.userParams.ymin_m.type = 'numerical';
            obj.userParams.ymin_m.description = 'minimum y value [m]';

            obj.userParams.ymax_m.value = 4000;
            obj.userParams.ymax_m.type = 'numerical';
            obj.userParams.ymax_m.description = 'maximum y value [m]';

            obj.userParams.ySpacing_m.value = 50;
            obj.userParams.ySpacing_m.type = 'numerical';
            obj.userParams.ySpacing_m.description = 'y grid spacing [m]';

            obj.userParams.zmin_m.value = 5;
            obj.userParams.zmin_m.type = 'numerical';
            obj.userParams.zmin_m.description = 'minimum x value';

            obj.userParams.zmax_m.value = 1000;
            obj.userParams.zmax_m.type = 'numerical';
            obj.userParams.zmax_m.description = 'maximum x value';

            obj.userParams.zSpacing_m.value = 10;
            obj.userParams.zSpacing_m.type = 'numerical';
            obj.userParams.zSpacing_m.description = 'maximum Y value [m]';

        end

        function prepare(obj, saveLoc)
            
            
            ok =1;
        end
        function run(obj)
            if isempty(obj.MOD)
                obj.prepare
            end

        end
    end
end