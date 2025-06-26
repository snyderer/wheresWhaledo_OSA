classdef pamdata < handle
    % detector object for running a humpback whale detector using labeled detections from PAMGuard
    properties
        wheresWhaledo
        DET % Detections
        saveloc
        userParams
        internalParams
        pamData
    end
    methods
        function obj = pamdata(wheresWhaledo)
            obj.wheresWhaledo = wheresWhaledo;
        end

        function defineUserParams(obj)
            % This function will be called by detectorPanel to make a table
            % of parameters the user needs to set to run this detector.

            % list of required user-defined params needed for this detector
            % values are default values
            obj.userParams.PAMfileLocation.value = '';
            obj.userParams.PAMfileLocation.type = 'file';
            obj.userParams.PAMfileLocation.description = 'Location of PAM file';

            % used to test drop down menu, but not actually required. I'm keeping it here as an example:
%             obj.userParams.filterType.value = 'FIR'; 
%             obj.userParams.filterType.type = 'dropdown';
%             obj.userParams.filterType.options = {'FIR', 'butter', 'ellip'};
%             obj.userParams.filterType.description = 'Filter type';

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

        function setInternalParams(obj)
            % read in PAMGAURD table:
            opts = detectImportOptions(obj.userParams.PAMfileLocation);
            opts = setvaropts(opts,'UTC','InputFormat','MM/dd/uuuu HH:mm:ss.SSS');
            obj.pamData = readtable(obj.userParams.PAMfileLocation, opts);
            obj.pamData.time_ml = datenum(obj.pamData.UTC);

            obj.internalParams.recTable = obj.wheresWhaledo.arrayPanel.receiverTable.Data; % receiver table
            obj.internalParams.numRec = height(obj.internalParams.recTable); % number of receivers
            obj.internalParams.numTDOA = nchoosek(obj.internalParams.numRec, 2); % number of TDOAs per detection
            
            ixcov = 0;
            itdoa = 0;
            idx_xcorr = zeros(obj.internalParams.numTDOA, 1);
            recPairs =  zeros(obj.internalParams.numTDOA, 2);
            for i1 = 1:obj.internalParams.numRec
                for i2 = 1:obj.internalParams.numRec
                    ixcov = ixcov+1;
                    if i2>i1
                        itdoa = itdoa+1;
                        idx_xcorr(itdoa) = ixcov;
                        recPairs(itdoa, :) = [i1, i2];
                    end
                end
            end
            obj.internalParams.idx_xcorr = idx_xcorr;
            obj.internalParams.recPairs = recPairs;
        end
       
        function DET = run(obj, wavfile) % run detector
            % DET is the detection table output
            % wavfile is the file name and path to the wav file currently
            % being processed

            if isempty(obj.userParams.PAMfileLocation)
                fprintf('No PAM file provided. Enter path to PAM file')
                return
            end

            if isempty(obj.internalParams) % internal params have not been set
                obj.setInternalParams
            end

            % make sure we have the right values set:
            assert(isfile(wavfile) & strcmp(wavfile(end-3:end), '.wav'), 'invalid file type for input wav file')
                       
            % make sure PAMGAURD table has required variables:
            requiredVariables = {'freqMin', 'freqMax', 'UTC', 'duration'}; % required variable names 
            assert(all(ismember(requiredVariables, obj.pamData.Properties.VariableNames)), 'PAMGuard table missing required variables') 

            % get required values from wav file header:
            info = audioinfo(wavfile);
            fs = info.SampleRate;
            spd = 60*60*24; % seconds per day
            maxLags = ceil(obj.userParams.maxTDOA*fs);

            fileLength_samples = info.TotalSamples;
            fileLength_s = fileLength_samples/fs;
            fileStartTime = datenum(wavfile(end-18:end-4), 'yyyymmdd-HHMMSS');
            fileEndTime = fileStartTime + fileLength_s/spd;

            % Trim PAMGAURD table to just those detections within in current wav file:
            T = obj.pamData(obj.pamData.time_ml>=fileStartTime & obj.pamData.time_ml<=fileEndTime, :);

            % band reject filter (ping removal):
            [breject, areject] = butter(obj.userParams.rejFilterOrder, (obj.userParams.rejFilterFreq + [-300, 300]).*2./fs, 'stop');

            numDet = height(T);

            TDOA = nan(numDet, obj.internalParams.numTDOA);
            XAmp = TDOA;
            TDet = nan(numDet, 1);
            for nt = 1:numDet
                f1 = max([T.freqMin(nt), 1]);
                f2 = min([T.freqMin(nt), fs/2]);
                
                if f2-f1 < 5 % too narrowband for default bandpass filter
                    f = max([f1, f2]);
                    b = fir1(obj.userParams.filterOrder, [f-5, f+5].*2./fs, 'bandpass');
                else
                    b = fir1(obj.userParams.filterOrder, [f1, f2].*2./fs, 'bandpass');
                end

                TDet(nt) = T.time_ml(nt);

                t1 = TDet(nt) - (T.duration(nt)+obj.userParams.maxTDOA)/spd; % start time of current window
                t2 = t1 + (3*T.duration(nt)+obj.userParams.maxTDOA)/spd; % end time of current window

                n1 = max([1, floor((t1-fileStartTime)*fs*spd)]); % start sample
                n2 = min([fileLength_samples, ceil((t2-fileStartTime)*fs*spd)]); % end sample

                x = audioread(wavfile, [n1, n2]);
                x = filtfilt(b, 1, x);
                x = filtfilt(breject, areject, x);

                [xc, lags] = xcov(x, maxLags);
                for npair = 1:obj.internalParams.numTDOA
                    [xcmax, imax] = max(xc(:, obj.internalParams.idx_xcorr(npair)));
                    TDOA(nt, npair) = lags(imax)/fs;
                    XAmp(nt, npair) = xcmax;
                end
            end
           
            DET = table;
            DET.TDOA = TDOA;
            DET.TDet = TDet;
            DET.XAmp = XAmp;
        end
    end
end