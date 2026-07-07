function errorMessage = makeMovie_2D(LOC, hydLoc, saveFileName, speedUpRate, params)
% makeMovie(whaleTable, hydLoc, saveFileName)
% makeMovie(whaleTable,  hydLoc, saveFileName, speedUpRate)
% makeMovie(whaleTable,  hydLoc, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps)
% makeMovie(whaleTable,  hydLoc, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps, params)
% errorMessage = makeMovie(whaleTable,  hydLoc, saveFileName, speedUpRate, cameraAngle, cameraAngle_timeStamps, params)
% whaleTable : a struct of whale tables from Where's Whaledo
% hydLoc : receiver table or matrix of hydrophone locations (in meters)
% saveFileName : file path and name
% speedUpRate : how much real-world time passes compared to video time (default 10x speed up)

if nargin<2; hydLoc = nan(1, 3); end
if istable(hydLoc)
    tmp = hydLoc;
    hydLoc = [tmp.x_m, tmp.y_m, tmp.z_m];
end
if nargin<3; saveFileName = './movie.mp4'; end
if nargin<4; speedUpRate = 60; end

if nargin<5 || ~isfield(params, 'colors')
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
numWhales = numel(LOC);
if any(params.colors(1, :)~=[0,0,0])
    baseColors = [0, 0, 0];   % unlabeled whales stay black
    params.colors = [baseColors; params.colors];
end

TDet_min = nan;
TDet_max = nan;
for iw = 1:numel(LOC)
    TDet_min = min([TDet_min, min(LOC{iw}.TDet)]);
    TDet_max = max([TDet_max, max(LOC{iw}.TDet)]);
end

frameRate = 10;
T = TDet_min:speedUpRate/(frameRate*60*60*24):TDet_max;

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

if any(strcmp(LOC{1}.Properties.VariableNames, 'x_m'))
    for iw = 1:numel(LOC)
        x(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.x_m, T, 'nearest');
        y(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.y_m, T, 'nearest');
                
        if any(strcmp(LOC{1}.Properties.VariableNames, 'x_m_smooth'))
            xsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.x_m_smooth, T);
            ysm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.y_m_smooth, T);
        else
            xsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.x_m, T, 'linear');
            ysm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.y_m, T, 'linear');
        end

        CI95_x_lo(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_x(:, 1), T, 'nearest');
        CI95_x_hi(:, iw) = interp1(LOC{iw}.TDet,  LOC{iw}.CI95_x(:, 2), T, 'nearest');

        CI95_y_lo(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_y(:, 1), T, 'nearest');
        CI95_y_hi(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_y(:, 2), T, 'nearest');
    end
elseif any(strcmp(LOC{1}.Properties.VariableNames, 'loc'))
    for iw = 1:numel(LOC)
        x(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 1), T, 'nearest');
        y(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 2), T, 'nearest');
        z(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 3), T, 'nearest');

        if any(strcmp(LOC{1}.Properties.VariableNames, 'loc_smooth'))
            xsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.x_m_smooth, T);
            ysm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.y_m_smooth, T);
            zsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.z_m_smooth, T);
        else
            xsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 1), T, 'linear');
            ysm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 2), T, 'linear');
            zsm(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.loc(:, 3), T, 'linear');
        end

        CI95_x_lo(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_x(:,1), T, 'nearest');
        CI95_x_hi(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_x(:,2), T, 'nearest');

        CI95_y_lo(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_y(:,1), T, 'nearest');
        CI95_y_hi(:, iw) = interp1(LOC{iw}.TDet, LOC{iw}.CI95_y(:,2), T, 'nearest');
    end
else
    warning('invalid input format')
    return
end


if isfield(params, 'xlim')
    xlimVals = params.xlim;
else
    xlimVals = [min([CI95_x_lo; hydLoc(:, 1)]), max([CI95_x_hi; hydLoc(:, 1)])];
    xlimVals = xlimVals + diff(xlimVals).*[-.1, .1];
end
if isfield(params, 'ylim')
    ylimVals = params.ylim;
else
    ylimVals = [min([CI95_y_lo; hydLoc(:, 2)]), max([CI95_y_hi; hydLoc(:, 2)])];
    ylimVals = ylimVals + diff(ylimVals).*[-.1, .1];
end

CI95_x_lo(isnan(CI95_x_lo)) = params.xlim(1);
CI95_x_hi(isnan(CI95_x_hi)) = params.xlim(2);
CI95_y_lo(isnan(CI95_y_lo)) = params.ylim(1);
CI95_y_hi(isnan(CI95_y_hi)) = params.ylim(2);

% begin plotting and saving video frames:
vidfile = VideoWriter(saveFileName,'MPEG-4');
vidfile.FrameRate = frameRate;
open(vidfile);
fig = figure;
plot(hydLoc(:, 1), hydLoc(:,2), 'ks')
xlim(xlimVals)
ylim(ylimVals)
axis equal

xlimVals = fig.Children.XLim;
ylimVals = fig.Children.YLim;
try
    for i = 1:length(T)
        for iw = 1:numWhales
            xci = linspace(CI95_x_lo(i, iw),CI95_x_hi(i, iw), 100);
            yci = linspace(CI95_y_lo(i, iw),CI95_y_hi(i, iw), 100);
            
            % Skipping just the "imagesc" block when CI95 values are NaN (JS)
            if ~any(isnan(xci)) && ~any(isnan(yci)) 
                [xci_mesh, yci_mesh] = meshgrid(xci, yci);
                dist = sqrt((xci_mesh - x(i, iw)).^2 + (yci_mesh - y(i, iw)).^2);
                L = -dist.^2;
                imagesc(xci, yci, L)
                colormap(flipud(gray))
                set(gca, 'YDir', 'normal')
            end

            [xci_mesh, yci_mesh] = meshgrid(xci, yci);

            dist = sqrt((xci_mesh - x(i, iw)).^2 + (yci_mesh - y(i, iw)).^2);
            L = -dist.^2;

            imagesc(xci, yci, L)
            colormap(flipud(gray))
            set(gca, 'YDir', 'normal')

            hold on
            %plot(xsm(1:i, iw), ysm(1:i, iw), 'Color', params.colors(iw+1, :))
            plot(x(i, iw), y(i, iw), '.', 'MarkerSize', 24, 'Color', params.colors(iw+1, :))
            plot(hydLoc(:, 1), hydLoc(:,2), 'ks')
        end
        hold off
        xlim(xlimVals)
        ylim(ylimVals)
        xlabel('x [m]')
        ylabel('y [m]')
        title(datestr(T(i), 'yyyy-mmm-dd HH:MM:SS'))
        drawnow
        F(i) = getframe(fig);
        writeVideo(vidfile, F(i));
    end
    close(vidfile)
catch ME
    errorMessage = ME;
    errorMessage
    close(vidfile)
end