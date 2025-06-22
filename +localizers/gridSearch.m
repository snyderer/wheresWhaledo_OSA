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

            obj.userParams.xmin_m.value = -2000;
            obj.userParams.xmin_m.type = 'numerical';
            obj.userParams.xmin_m.description = 'minimum x value [m]';

            obj.userParams.xmax_m.value = 2000;
            obj.userParams.xmax_m.type = 'numerical';
            obj.userParams.xmax_m.description = 'maximum x value [m]';

            obj.userParams.xSpacing_m.value = 20;
            obj.userParams.xSpacing_m.type = 'numerical';
            obj.userParams.xSpacing_m.description = 'x grid spacing [m]';

            obj.userParams.ymin_m.value = -2000;
            obj.userParams.ymin_m.type = 'numerical';
            obj.userParams.ymin_m.description = 'minimum y value [m]';

            obj.userParams.ymax_m.value = 2000;
            obj.userParams.ymax_m.type = 'numerical';
            obj.userParams.ymax_m.description = 'maximum y value [m]';

            obj.userParams.ySpacing_m.value = 20;
            obj.userParams.ySpacing_m.type = 'numerical';
            obj.userParams.ySpacing_m.description = 'y grid spacing [m]';

            obj.userParams.zmin_m.value = 20;
            obj.userParams.zmin_m.type = 'numerical';
            obj.userParams.zmin_m.description = 'minimum x value';

            obj.userParams.zmax_m.value = 20;
            obj.userParams.zmax_m.type = 'numerical';
            obj.userParams.zmax_m.description = 'maximum x value';

            obj.userParams.zSpacing_m.value = 10;
            obj.userParams.zSpacing_m.type = 'numerical';
            obj.userParams.zSpacing_m.description = 'maximum Y value [m]';

            obj.userParams.soundSpeed_mps.value = 1500;
            obj.userParams.soundSpeed_mps.type = 'numerical';
            obj.userParams.soundSpeed_mps.description = 'average sound speed in meters per second';

            obj.userParams.windowLength.value = 1;
            obj.userParams.windowLength.type = 'numerical';
            obj.userParams.windowLength.description = 'length of window for smoothing [samples]. =0 means no smoothing.';

            obj.userParams.sigma.value = 10;
            obj.userParams.sigma.type = 'numerical';
            obj.userParams.sigma.description = 'Standand dev. of hydrophone positions [m]';
        end

        function defineInternalParams(obj)
            obj.internalParams.maxModelInActiveMemory_kb = 50e3; % maximum size of file in active memory at a given time in kilobytes
            obj.DET = obj.wheresWhaledo.detectorPanel.DET;
        end
        function [MOD] = prepare(obj, saveLoc)
            % the prepare function builds a model or sets and saves the
            % parameters required for localization.
            
            obj.defineInternalParams

            % build x,t,z grid:
            obj.MOD.x_m = obj.userParams.xmin_m:obj.userParams.xSpacing_m:obj.userParams.xmax_m;
            obj.MOD.y_m = obj.userParams.ymin_m:obj.userParams.ySpacing_m:obj.userParams.ymax_m;
            obj.MOD.z_m = obj.userParams.zmin_m:obj.userParams.zSpacing_m:obj.userParams.zmax_m;
            
            obj.internalParams.Ngridpoints = length(obj.MOD.x_m)*length(obj.MOD.y_m)*length(obj.MOD.z_m);

            obj.MOD.recloc_m = [obj.wheresWhaledo.arrayPanel.receiverTable.Data.x_m, ...
                obj.wheresWhaledo.arrayPanel.receiverTable.Data.y_m, ...
                obj.wheresWhaledo.arrayPanel.receiverTable.Data.z_m];

            obj.internalParams.Nrec = size(obj.MOD.recloc_m, 1);

            % determine hydrophone pairs:
            obj.internalParams.NhydPairs = nchoosek(obj.internalParams.Nrec, 2); % number of unique hydrophone pairs
            obj.MOD.hydPairs = zeros(obj.internalParams.NhydPairs, 2);
            ipair = 0;
            for ih1 = 1:obj.internalParams.Nrec-1
                for ih2 = ih1+1:obj.internalParams.Nrec
                    ipair = ipair+1;
                    obj.MOD.hydPairs(ipair, :) = [ih1, ih2];
                end
            end
            
            if obj.internalParams.Ngridpoints < obj.internalParams.maxModelInActiveMemory_kb*8000
                % whole model can be in active memory
                [x, y, z] = ndgrid(obj.MOD.x_m, obj.MOD.y_m, obj.MOD.z_m); 
                obj.MOD.grid = [x(:), y(:), z(:)];
                
                % estimate TDOAs:
                R = zeros(obj.internalParams.Ngridpoints, obj.internalParams.Nrec);
                for ir = 1:obj.internalParams.Nrec
                    R(:, ir) = sqrt(sum((obj.MOD.grid-obj.MOD.recloc_m(ir, :)).^2, 2));
                end
                obj.MOD.TDOA = zeros(obj.internalParams.Ngridpoints, obj.internalParams.NhydPairs);
                for itdoa = 1:obj.internalParams.NhydPairs
                    obj.MOD.TDOA(:, itdoa) = (R(:, obj.MOD.hydPairs(itdoa, 1)) - R(:, obj.MOD.hydPairs(itdoa, 2)))./obj.userParams.soundSpeed_mps;
                end
                MOD = obj.MOD;
                save(obj.wheresWhaledo.localizePanel.saveModelLocation, 'MOD')
            else
                % model must be built, saved, and loaded in smaller sections
                % TO DO
                fprintf('LARGE MODEL COMPATIBILITY NOT COMPLETE\n Please reduce model size and try again')
            end
        end
        function LOC = run(obj)
            if isempty(obj.MOD) % if model hasn't been generated, make one
                if exist(obj.wheresWhaledo.localizePanel.saveModelLocation, 'file')
                    load(obj.wheresWhaledo.localizePanel.saveModelLocation) % load existing model
                    % to do! if model is too large, only load segments
                else
                    obj.prepare
                end
            end
            sigma = sqrt(2*obj.userParams.sigma^2/1500^2 + .01^2);

            whaleNums = unique(obj.DET.label(obj.DET.label>0));
            for iw = 1:length(whaleNums)
                DETidx = find(obj.DET.label==whaleNums(iw));
                [~, tmp] = unique(obj.DET.TDet(DETidx));
                DETidx = DETidx(tmp);
                
                

                Ndet = length(DETidx);
                obj.LOC{iw} = obj.DET(DETidx, :);
                obj.LOC{iw}.x_m = nan(Ndet, 1);
                obj.LOC{iw}.y_m = nan(Ndet, 1);
                obj.LOC{iw}.z_m = nan(Ndet, 1);
                obj.LOC{iw}.CI95_x = nan(Ndet, 2);
                obj.LOC{iw}.CI95_y = nan(Ndet, 2);
                obj.LOC{iw}.CI95_z = nan(Ndet, 2);

                switch obj.userParams.windowLength
                    case 0 % no interpolation
                        obj.LOC{iw}.TDOAi = obj.LOC{iw}.TDOA;
                    case 1 % replace nans with nearest neighbor
                        obj.LOC{iw}.TDOAi = obj.LOC{iw}.TDOA;
                        for itdoa = 1:obj.internalParams.NhydPairs
                            idxNotNan = ~isnan(obj.LOC{iw}.TDOA(:, itdoa));
                            obj.LOC{iw}.TDOAi(:, itdoa) = interp1(obj.LOC{iw}.TDet(idxNotNan),...
                                obj.LOC{iw}.TDOA(idxNotNan, itdoa), obj.LOC{iw}.TDet, 'nearest', 'extrap');
                        end
                    otherwise % smooth with moving average
                        obj.LOC{iw}.TDOAi = obj.LOC{iw}.TDOA;
                        for itdoa = 1:obj.internalParams.NhydPairs
                            idxNotNan = ~isnan(obj.LOC{iw}.TDOA(:, itdoa));
                            obj.LOC{iw}.TDOAi(:, itdoa) = interp1(obj.LOC{iw}.TDet(idxNotNan),...
                                obj.LOC{iw}.TDOA(idxNotNan, itdoa), obj.LOC{iw}.TDet, 'nearest', 'extrap');
                            obj.LOC{iw}.TDOAi(:, itdoa) = movmean(obj.LOC{iw}.TDOAi(:, itdoa), obj.userParams.windowLength, 'omitnan');
                        end
                end
                for idet = 1:Ndet
                    numNotNan = sum(~isnan(obj.LOC{iw}.TDOAi(idet, :)));
                    err = sum((obj.MOD.TDOA - obj.LOC{iw}.TDOAi(idet, :)).^2, 2);
                    L = 1/(2*pi*sigma^2)^numNotNan * exp(-1/(2*sigma^2).*err);
                    [~, idxMax] = max(L);

                    obj.LOC{iw}.x_m(idet, :) = obj.MOD.grid(idxMax, 1);
                    obj.LOC{iw}.y_m(idet, :) = obj.MOD.grid(idxMax, 2);
                    obj.LOC{iw}.z_m(idet, :) = obj.MOD.grid(idxMax, 3);

                    idxX = (obj.MOD.grid(:, 2)==obj.MOD.grid(idxMax, 2)) & (obj.MOD.grid(:, 3)==obj.MOD.grid(idxMax, 3));
                    idxY = (obj.MOD.grid(:, 1)==obj.MOD.grid(idxMax, 1)) & (obj.MOD.grid(:, 3)==obj.MOD.grid(idxMax, 3));
                    idxZ = (obj.MOD.grid(:, 1)==obj.MOD.grid(idxMax, 1)) & (obj.MOD.grid(:, 2)==obj.MOD.grid(idxMax, 2));

                    Lx = L(idxX);
                    Ly = L(idxY);
                    Lz = L(idxZ);

                    Cx = cumsum(Lx)./sum(Lx); 
                    Cy = cumsum(Ly)./sum(Ly);
                    Cz = cumsum(Lz)./sum(Lz);

                    obj.LOC{iw}.CI95_x(idet, 1) = max([obj.MOD.x_m(Cx<=.025), nan]);
                    obj.LOC{iw}.CI95_x(idet, 2) = min([obj.MOD.x_m(Cx>=.975), nan]);
                    obj.LOC{iw}.CI95_y(idet, 1) = max([obj.MOD.y_m(Cy<=.025), nan]);
                    obj.LOC{iw}.CI95_y(idet, 2) = min([obj.MOD.y_m(Cy>=.975), nan]);
                    obj.LOC{iw}.CI95_z(idet, 1) = max([obj.MOD.z_m(Cz<=.025), nan]);
                    obj.LOC{iw}.CI95_z(idet, 2) = min([obj.MOD.z_m(Cz>=.975), nan]);
                end
            end
            
            LOC = obj.LOC;
            
            save(obj.wheresWhaledo.localizePanel.saveLocalizationsLocation, "LOC")
        end
    end
end