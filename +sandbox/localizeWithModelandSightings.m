% load('D:\OSA\wheresWhaledo_OSA\Dep1.1\arrayConfig.mat.mat')
% load('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\brushed.mat')

load('D:\OSA\Localization_Files\Dep1.2_Mn_UID05a\brushed.mat')
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')
vidFilePathName = 'D:\OSA\wheresWhaledo_OSA\Dep1.2\MN05.mp4';

% interpFlag = true; 
interpFlag = false; 

sightingLoc = [-3.3111e3, 995.34];

numTDOA = size(DET.TDOA, 2);
%% make model:

xmod = -5000:20:5000;
ymod = -5000:20:5000;

[X, Y] = meshgrid(xmod, ymod);
X = X(:);
Y = Y(:);
zmod = 10;
c = 1500;

mTDOA = zeros(length(X), numTDOA);
i = 0;
for i1 = 1:size(receiverTable, 1)
    for i2 = (i1+1):size(receiverTable, 1)
        i = i+1;
        mTDOA(:, i) = -(sqrt((X-receiverTable.("x [m]")(i1)).^2 + (Y-receiverTable.("z [m]")(i1)).^2 + (zmod-receiverTable.("z [m]")(i1)).^2)./c ...
            - sqrt((X-receiverTable.("x [m]")(i2)).^2 + (Y-receiverTable.("z [m]")(i2)).^2 + (zmod-receiverTable.("z [m]")(i2)).^2)./c);
    end
end

if interpFlag
    TDOAi = DET.TDOA;
    for i = 1:size(DET.TDOA, 2)
        idxWhale = find(~isnan(DET.TDOA(:, i)));
        TDOAi(:, i) = interp1(DET.TDet(idxWhale), DET.TDOA(idxWhale, i), DET.TDet);
    end
else
    TDOAi = DET.TDOA;
end

DET = sortrows(DET, 'TDet');
idxRem = find(sum(~isnan(DET.TDOA), 2)<3);
DET(idxRem, :) = [];

[~, idxUnique] = unique(DET.TDet);
DET = DET(idxUnique, :);

num1perc = round(length(X).*.01); % number of points in top 1% 
whaleNums = unique(DET.label);


for iwhale = 1:length(whaleNums)
    idxWhale = find(DET.label==whaleNums(iwhale));
    whale{iwhale} = table;
    whale{iwhale}.TDet = DET.TDet(idxWhale);
    whale{iwhale}.loc = nan(length(idxWhale), 3);
    whale{iwhale}.top1percIdx = nan(length(idxWhale), 3, num1perc);
    
    % TO DO: smooth and interpolate TDOAs
    idxStart = 0;
    idxEnd = length(idxWhale);
    tdoa = nan(size(DET.TDOA(idxWhale, :)));
    for itdoa = 1:numTDOA
        idx1 = find(~isnan(DET.TDOA(idxWhale, itdoa)), 1, 'first');
        idxStart = max([idxStart, idx1]);
        idx1 = find(~isnan(DET.TDOA(idxWhale, itdoa)), 1, 'last');
        idxEnd = min([idxEnd, idx1]);

        idxNotNan = find(~isnan(DET.TDOA(idxWhale, itdoa)));
        tdoa(:, itdoa) = interp1(DET.TDet(idxWhale(idxNotNan)), DET.TDOA(idxWhale(idxNotNan), itdoa), DET.TDet(idxWhale), 'linear', 'extrap');
    end
    t = DET.TDet(idxWhale(idxStart)):(1/(60*60*24)):whale{iwhale}.TDet(idxWhale(idxEnd));
    tdoai = interp1(DET.TDet(idxWhale), tdoa, t);
    
    tdoai = movmedian(tdoai, 30);

    vidfile = VideoWriter(vidFilePathName,'MPEG-4');
    open(vidfile);
    for i = 1:length(tdoai)
        numNotNan = sum(~isnan(tdoai(i, :)));
        err = sum((mTDOA - tdoai(i, :)).^2, 2, 'omitnan')./numNotNan;
        [minErr, idx01] = mink(err, num1perc);
        
        whale{iwhale}.loc(i, :) = [X(idx01(1)), Y(idx01(1)), zmod];

        fig = figure(11);
        set(fig, 'Position', [40, 40, 700, 700])
        plot(receiverTable.('x [m]'), receiverTable.('y [m]'), 'ks', 'MarkerFaceColor', [.244, .244, .766])
        hold on
        axis([-5000, 5000, -5000, 5000])
        axis square
        grid on
        xlabel('E-W [m]')
        ylabel('N-S [m]')
        scatter(X(idx01), Y(idx01), [], 1./minErr, 'filled')
        plot(X(idx01(1)), Y(idx01(1)), 'rx', 'LineWidth', 2)
        title(datestr(t(i)))
        hold off
        colormap gray
        drawnow

        F(i) = getframe(gca);
        writeVideo(vidfile, F(i));
        
    end
    
    close(vidfile)
end