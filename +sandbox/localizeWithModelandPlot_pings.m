% load('D:\OSA\wheresWhaledo_OSA\Dep1.1\arrayConfig.mat.mat')
% load('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\brushed.mat')

pingLoc = readtable('D:\OSA\Localization_Files\Pings\JJVessel_Pinger_Locations.csv');
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')
saveFilePathName = 'D:\OSA\wheresWhaledo_OSA\Dep1.2\pings.png';

plotFlag = true;

sigma = sqrt(2*(10^2)/1500^2 + .001^2);
spd = 60*60*24;
fs = 192000;
c = 1500;

maxTDOA = max(sqrt((receiverTable.x_m - receiverTable.x_m.').^2 + ...
    (receiverTable.y_m - receiverTable.y_m.').^2 + ...
    (receiverTable.z_m - receiverTable.z_m.').^2), [], 'all')./c;

maxlag = ceil(maxTDOA*fs.*2);
chunksize = 10*fs; % data chunk size (max number read in for xcorr)
stepSize = 5*fs;

[xship, yship] = utils.latlon2xy(pingLoc.Latitude, pingLoc.Longitude, 36.788031, -121.9054973);

pingLoc.x = xship;
pingLoc.y = yship;
numRec = height(receiverTable);
numTDOA = nchoosek(numRec, 2);
expTDOA = zeros(numTDOA, length(xship));
indXcorr = zeros(numTDOA, 1);
recPairs = zeros(numTDOA, 2);
maxlags = indXcorr;
itdoa = 0;
ixcov = 0;
for i1 = 1:numRec
    for i2 = 1:numRec
        ixcov = ixcov+1;
        if i2>i1
            itdoa = itdoa+1;
            r1 = sqrt((receiverTable.x_m(i1)-xship).^2 + (receiverTable.y_m(i1)-yship).^2 + (receiverTable.z_m(i1)-0).^2);
            r2 = sqrt((receiverTable.x_m(i2)-xship).^2 + (receiverTable.y_m(i2)-yship).^2 + (receiverTable.z_m(i2)-0).^2);
            expTDOA(itdoa, :) = (r1-r2)./c;
            indXcorr(itdoa) = ixcov;
            recPairs(itdoa, :) = [i1, i2];
            maxlags(itdoa) = ceil(1.5*sqrt((receiverTable.x_m(i1)-receiverTable.x_m(i2)).^2 + (receiverTable.y_m(i1)-receiverTable.y_m(i2)).^2 + (receiverTable.z_m(i1)-0).^2).*fs/c);
        end
    end
end

%% Make DET table from pingLoc table
% [b, a] = fir1(40, [35000, 45000]*2/fs);
[b, a] = ellip(6, 5, 80, [37000, 41000]*2/fs);
fc = 38.8e3;
dur = round((1.2e-3)*fs); % ping duration
ker = sin(2*pi*(1:dur).*fc./fs).*tukeywin(dur, .4).';
baseFilePath = 'D:\OSA\Localization_Files\Pings';
TDOA = nan(height(pingLoc)*100, numTDOA);
TDet = nan(height(pingLoc)*100, 1);
label = TDet;
idet = 0;
for ip = 1:height(pingLoc)
    fileStartTime = datenum(pingLoc.fileName{ip}(end-18:end-4), 'yyyymmdd-HHMMSS');
    pingStartTime = datenum(pingLoc.startTime(ip));
    pingEndTime = datenum(pingLoc.endTime(ip));
    info = audioinfo(fullfile(baseFilePath, pingLoc.fileName{ip}));
    nstart = max([1, round((pingStartTime - fileStartTime).*spd*fs)]);
    nend = min([info.TotalSamples, round((pingEndTime - fileStartTime).*spd*fs)]);

    n1 = nstart;
    n3 = n1 + chunksize - 1;
    data = audioread(fullfile(baseFilePath, pingLoc.fileName{ip}), [n1, n3]);
    data = filter(b, a, data);
%     for irec = 1:numRec
%         data(:, irec) = conv(data(:, irec), ker, "same");
%     end
    while n3<nend
        idet = idet+1;
       
%         data = filter(b, a, data);
        TDet(idet) = ((n1+n3)/2)/(fs*spd) + fileStartTime;
        label(idet) = ip;
        
        % find peaks nearest to the expected TDOA
        for itdoa = 1:length(indXcorr)

            [xc, lags] = xcorr(data(:, recPairs(itdoa, 1)), data(:, recPairs(itdoa, 2)), maxlags(itdoa));
            
            N = mean(abs(xc));

            [pks, locs] = findpeaks(xc./N, 'MinPeakHeight', 5, 'MinPeakDistance', 1e5, 'NPeaks', 4);
            if ~isempty(locs)
                potentialTDOAs = lags(locs)./fs;
                [~, idx] = min(abs(potentialTDOAs-expTDOA(itdoa, ip)));
                TDOA(idet, itdoa) = potentialTDOAs(idx);
            else
                ok =1;
            end
        end

        n1 = n1+stepSize;
        n2 = min([n3+1, info.TotalSamples-1]);
        n3 = min([n1+chunksize-1, info.TotalSamples]);

        newdata = audioread(fullfile(baseFilePath, pingLoc.fileName{ip}), [n2, n3]);
        for irec = 1:numRec
            newdata(:, irec) = conv(newdata(:, irec), ker, "same");
        end
        data = [data(stepSize+1:end, :); newdata];
ok =1;
    end
    
end

% remove nans:
irem = isnan(TDet);
TDet(irem) = [];
TDOA(irem, :) = [];
label(irem) = [];
figure(99)

%% make into table
DET = table;
DET.TDet = TDet;
DET.TDOA = TDOA;
DET.label = label;

for itdoa = 1:length(indXcorr)
        subplot(6, 1, itdoa)
        scatter(DET.TDet, DET.TDOA(:, itdoa), 12, DET.label, 'filled')
end

str = 'c';
for i = 1:height(pingLoc)
    idx = find(DET.label==i);
    D = DET(idx, :);
    D.label = zeros(height(D), 1);
    tmp = gui.brushTDOA(D);
    pause(.1)
    str = input('Continue: ', "s");

    DET.TDOA(idx, :) = tmp.data.TDOA;
    
    
end

%%
newDet = height(pingLoc);
for i = 1:height(pingLoc)
    idx = find(DET.label==i);
    D = DET(idx, :);
    D.label = zeros(height(D), 1);
    tmp = gui.brushTDOA(D);
    pause(.1)
    str = input('Continue: ', "s");

    DET.TDOA(idx, :) = tmp.data.TDOA;
    
    
end

%%
pingLoc.expTDOA = expTDOA.';
pingLoc.measTDOA = nan(size(expTDOA.'));
pingLoc.sigmaTDOA = nan(size(expTDOA.'));
for i = 1:height(pingLoc)
    idx = find(DET.label==i);
    pingLoc.measTDOA(i, :) = mean(DET.TDOA(idx, :), 'omitnan');
    pingLoc.sigmaTDOA(i, :) = std(DET.TDOA(idx, :), 'omitnan');
end

save('brushed_pings', 'pingLoc')

%% make model:

xmod = -5000:10:2000;
ymod = -2000:10:2000;
zmod = 10;
[X, Y, Z] = meshgrid(xmod, ymod, zmod);
X = X(:);
Y = Y(:);
Z = Z(:);


mTDOA = zeros(length(X), numTDOA);
itdoa = 0;
for i1 = 1:size(receiverTable, 1)
    for i2 = (i1+1):size(receiverTable, 1)
        itdoa = itdoa+1;
        mTDOA(:, itdoa) = (sqrt((X-receiverTable.("x [m]")(i1)).^2 + (Y-receiverTable.("y [m]")(i1)).^2 + (Z-receiverTable.("z [m]")(i1)).^2)./c ...
            - sqrt((X-receiverTable.("x [m]")(i2)).^2 + (Y-receiverTable.("y [m]")(i2)).^2 + (Z-receiverTable.("z [m]")(i2)).^2)./c);
    end
end

save('D:\OSA\wheresWhaledo_OSA\Dep1.2\model_surface_pings.mat', 'mTDOA', 'X', 'Y', 'Z')

%%
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\model_surface_pings.mat')
load('brushed_pings.mat')

whale{1} = table;
whale{1}.loc = nan(height(pingLoc), 3);
whale{1}.CI95_x = nan(height(pingLoc), 2);
whale{1}.CI95_y = whale{1}.CI95_x;
whale{1}.CI95_z = whale{1}.CI95_x;

sigma_h = sqrt(2*(20^2)/c^2);

for i = 1:height(pingLoc)
    numNotNan = sum(~isnan(pingLoc.measTDOA(i, :)));
    sigma = sqrt(sigma_h.^2 + sum(pingLoc.sigmaTDOA(i, :).^2));
    err = sum((mTDOA - pingLoc.measTDOA(i, :)).^2, 2, 'omitnan');
    L = 1/(2*pi.*sigma^2).^numNotNan.*exp(-1./(2*sigma.^2).*err);
    [maxL, idxMax] = max(L);
    whale{1}.loc(i, :) = [X(idxMax), Y(idxMax), Z(idxMax)];

          % calculate confidence intervals:
        idxX = find((Y==Y(idxMax) & Z==Z(idxMax)));
        idxY = find((X==X(idxMax) & Z==Z(idxMax)));
        idxZ = find((X==X(idxMax) & Y==Y(idxMax)));
        
        Lx = L(idxX);
        Ly = L(idxY);
        Lz = L(idxZ);

        Cx = cumsum(Lx)./sum(Lx); %Cx = Cx-min(Cx); Cx = Cx./max(Cx);
        Cy = cumsum(Ly)./sum(Ly); %Cy = Cy-min(Cy); Cy = Cy./max(Cy);
        Cz = cumsum(Lz)./sum(Lz); %Cz = Cz-min(Cz); Cz = Cz./max(Cz);
        whale{1}.sigma(i) = sigma;
        whale{1}.CI95_x(i, 1) = max([xmod(Cx<=.025), nan]);
        whale{1}.CI95_x(i, 2) = min([xmod(Cx>=.975), nan]);
        whale{1}.CI95_y(i, 1) = max([ymod(Cy<=.025), nan]);
        whale{1}.CI95_y(i, 2) = min([ymod(Cy>=.975), nan]);
        whale{1}.CI95_z(i, 1) = max([zmod(Cz<=.025), nan]);
        whale{1}.CI95_z(i, 2) = min([zmod(Cz>=.975), nan]);
end

%%
col = lines(3);
fig = figure(5);
set(fig, 'Position', [488 122 969 639])
idx = find(whale{1}.sigma<.025);

plot([pingLoc.x(idx), whale{1}.loc(idx,1)].', [pingLoc.y(idx), whale{1}.loc(idx, 2)].', 'k:')
hold on
p1 = plot(whale{1}.loc(idx,1), whale{1}.loc(idx, 2), 'x', 'LineWidth', 2, 'markersize', 11, 'color', col(2, :));
for i = 1:length(idx)
    text(whale{1}.loc(idx(i), 1)+25, whale{1}.loc(idx(i), 2)+25, sprintf('ping %i', pingLoc.Ping(idx(i))));
end
plot(whale{1}.CI95_x(idx, :).', [whale{1}.loc(idx, 2), whale{1}.loc(idx, 2)].', 'k');
plot([whale{1}.loc(idx, 1), whale{1}.loc(idx, 1)].', whale{1}.CI95_y(idx, :).', 'k');
pci = plot(nan, nan, 'k');
p2 = plot(pingLoc.x(idx), pingLoc.y(idx), 'o', 'LineWidth', 2, 'color', col(1, :));
p3 = plot(receiverTable.x_m, receiverTable.y_m, 'ks');
for ih = 1:height(receiverTable)
    text(receiverTable.x_m(ih)+40, receiverTable.y_m(ih), sprintf('hyd %i', ih));
end
hold off
grid on
ylim([-2000, 1500])
xlim([-2500, 2500])
axis equal
xlabel('E-W [m]')
ylabel('N-S [m]')
legend([p1, p2, pci, p3], 'localized position', 'reported position', '95% Confidence Interval', 'hydrophone locations', 'Location','eastoutside')

exportgraphics(fig, 'D:\OSA\wheresWhaledo_OSA\Dep1.2\PingLocalizations.png', 'Resolution',600)

%%
fig = figure(6); 
for i = 1:6
    subplot(3,2,i)
    plot(pingLoc.measTDOA(idx, i), 'x', 'MarkerSize', 14, 'LineWidth', 2); hold on; 
    plot(pingLoc.expTDOA(idx, i), '.', 'MarkerSize', 16); hold off
    title(sprintf('hydrophones %i - %i', recPairs(i, 1), recPairs(i, 2)))
    ylabel('TDOA [s]')
    if i ==1
        leg = legend('Measured TDOA', 'Expected TDOA');
        leg.Position = leg.Position + [.02, 0, 0, 0];
    end
    xlabel('ping number')
    grid on
end

set(fig, 'Position', [488 122 969 639])
exportgraphics(fig, 'D:\OSA\wheresWhaledo_OSA\Dep1.2\tdoaComparison.png', 'Resolution',600)
