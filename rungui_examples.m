%% scatter plot example:
% generate random data:
% Nplots = 10;
% TDet = (0:.5:60).';
% TDOA = randn(length(TDet), Nplots);
% DAmp = abs(randn(length(TDet), Nplots));
% XAmp = abs(randn(length(TDet), Nplots));
% labels = zeros(size(TDet));
% 
% DATA = table(TDet, TDOA, DAmp, XAmp, labels);
load('D:\OSA\sandbox\shiptrack\TDOA.mat')

% set params:
% params.figPosition = [4, 50, 1093, 732];
% params.TDOAdropdownWidth = .04;
% sc = brushTDOA(DET, params);

[irow, itdoa] = find(DET.XAmp<5);
DET.TDOA(irow, itdoa) = nan;


sc = brushTDOA(DET)


%%% TO DO
% 1. freehand tool
% 2. localize button
% 3. move TDOA drop-downs to top of corresponding TDOA plots
% 4. add threshold sliders
%      - how do I not display points without removing them from tables?
% 5. DEBUG: why is the undo not working?