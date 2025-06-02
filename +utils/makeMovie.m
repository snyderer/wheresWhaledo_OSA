function errorMessage = makeMovie(whaleTable, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps, params)
% makeMovie(whaleTable, saveFileName)
% makeMovie(whaleTable, saveFileName, speedUpRate)
% makeMovie(whaleTable, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps)
% makeMovie(whaleTable, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps, params)
% errorMessage = makeMovie(whaleTable, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps, params)
% whaleTable : a struct of whale tables from Where's Whaledo
% saveFileName : file path and name
% speedUpRate : how much real-world time passes compared to video time (default 10x speed up)
% cameraAngle : Nx2 matrix of [az, el] camera angles (passed into view() function)
% cameraAngle_timeStamps : Nx1 time stamps in datenum format associated with each row of cameraAngle

if nargin<2; saveFileName = './movie.mp4'; end
if nargin<3; speedUpRate = 10; end
if nargin<4; cameraAngle = [0, 90]; end
if nargin<5; cameraAngle_timeStamps = []; end
if nargin<6
    params.colors = [0, 0, 0; % unlabeled
        0.984314, 0.603922, 0.600000; % whale 1
        0.756863, 0.874510, 0.541176; % whale 2
        0.650980, 0.807843, 0.890196; % whale 3
        0.992157, 0.749020, 0.435294; % whale 4
        0.121569, 0.470588, 0.705882; % whale 5
        0.792157, 0.698039, 0.839216; % whale 6
        0.219608, 0.725490, 0.027451; % whale 7
        0.415686, 0.239216, 0.603922; % whale 8
        0.890196, 0.101961, 0.109804]; % whale 9
end
errorMessage = [];
numWhales = numel(whaleTable);

TDet_min = nan;
TDet_max = nan;
for iw = 1:numel(whaleTable)
    TDet_min = min([TDet_min, min(whaleTable{iw}.TDet)]);
    TDet_max = max([TDet_max, max(whaleTable{iw}.TDet)]);
end

T = TDet_min:/(60*60*24):TDet_max;

if isempty(cameraAngle_timeStamps) && size(cameraAngle, 1)>1
    cameraAngle_timeStamps = linspace(TDet_min, TDet_max, length(cameraAngle));
elseif size(cameraAngle, 1)==1
    cameraAngle = [cameraAngle; cameraAngle];
    cameraAngle_timeStamps = [TDet_min; TDet_max];
elseif length(cameraAngle_timeStamps)>1
    cameraAngle_timeStamps = [cameraAngle_timeStamps(1); cameraAngle_timeStamps(:); cameraAngle_timeStamps(end)];
    cameraAngle = [cameraAngle(1); cameraAngle; cameraAngle(end)];
end

cameraAngle = interp1(cameraAngle_timeStamps, cameraAngle, T);

x = zeros(length(T), numWhales);
y = x;
z = x;
xsm = x;
ysm = x;
zsm = x;
CI95_x_lo = x;
CI95_x_hi = x;
CI95_y_lo = x;
CI95_y_hi = x;
CI95_z_lo = x;
CI95_z_hi = x;

if any(strcmp(whaleTable{1}.Properties.VariableNames, 'loc_x'))
    for iw = 1:numel(whaleTable)
        x(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_x, T, 'nearest');
        y(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_y, T, 'nearest');
        z(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_z, T, 'nearest');
        
        if any(strcmp(whaleTable{1}.Properties.VariableNames, 'loc_x_smooth'))
            xsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_x_smooth, T);
            ysm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_y_smooth, T);
            zsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_z_smooth, T);
        else
            xsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_x, T, 'spline');
            ysm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_y, T, 'spline');
            zsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_z, T, 'spline');
        end

        CI95_x_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_x_lo, T, 'nearest');
        CI95_x_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_x_hi, T, 'nearest');

        CI95_y_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_y_lo, T, 'nearest');
        CI95_y_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_y_hi, T, 'nearest');

        CI95_z_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_z_lo, T, 'nearest');
        CI95_z_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_z_hi, T, 'nearest');
    end
elseif any(strcmp(whaleTable{1}.Properties.VariableNames, 'loc'))
    for iw = 1:numel(whaleTable)
        x(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc(:,1), T, 'nearest', 'spline');
        y(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc(:,2), T, 'nearest', 'spline');
        z(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc(:,3), T, 'nearest', 'spline');

        if any(strcmp(whaleTable{1}.Properties.VariableNames, 'loc_x_smooth'))
            xsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 1), T);
            ysm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 2), T);
            zsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 3), T);
        else
            xsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 1), T);
            ysm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 2), T);
            zsm(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.loc_smooth(:, 3), T);
        end

        CI95_x_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_x(:,1), T, 'nearest');
        CI95_x_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_x(:,2), T, 'nearest');

        CI95_y_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_y(:,1), T, 'nearest');
        CI95_y_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_y(:,2), T, 'nearest');

        CI95_z_lo(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_z(:,1), T, 'nearest');
        CI95_z_hi(:, iw) = interp1(whaleTable{iw}.TDet, whaleTable{iw}.CI95_z(:,2), T, 'nearest');
    end
else
    warning('invalid input format')
    return
end

% begin plotting and saving video frames:
vidfile = VideoWriter(saveFileName,'MPEG-4');
open(vidfile);
fig = figure;
try
    for i = 1:length(T)
        for iw = 1:numWhales
          
            hold on
            plot3(xsm(1:i, iw), ysm(1:i, iw), zsm(1:i, iw), 'Color', params.color(iw, :))
            plot3(x(i, iw), y(i, iw), z(i, iw), '.', 'MarkerSize', 24, 'Color', params.color(iw, :))
            
        end
        hold off
        F(i) = getframe(fig);
        view
        writeVideo(vidfile, F(i));
    end

    close(vidfile)
catch ME
    errorMessage = ME;
    close(vidfile)
end