% load ping table:
PING = readtable('D:\OSA\Localization_Files\Pings\JJVessel_Pinger_Locations.csv');
ARR = readtable('D:\OSA\Dep1.2_Recorder_Locations_Depths.csv');
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')

info = audioinfo('D:\OSA\Localization_Files\Pings\Ping7\M-20230808-193000.wav');
fs = info.SampleRate;
numRec = info.NumChannels;

spd = 60*60*24;
c = 1500;
ixcov = 0;
itdoa = 0;
rmax = 0;
for i1 = 1:numRec
    for i2 = 1:numRec
        ixcov = ixcov+1;
        if i2>i1
            r = sqrt((receiverTable.("x [m]")(i1) - receiverTable.("x [m]")(i2)).^2 + (receiverTable.("y [m]")(i1) - receiverTable.("y [m]")(i2)).^2+ (receiverTable.("z [m]")(i1) - receiverTable.("z [m]")(i2)).^2);
            rmax = max([rmax, r]);
            itdoa = itdoa+1;
            indXcorr(itdoa) = ixcov;
            recPairs(itdoa, :) = [i1, i2];
        end
    end
end

maxLags = round(fs*rmax/1470);

Ntdoa = length(indXcorr);

[xsrc, ysrc] = utils.latlon2xy(PING.Latitude, PING.Longitude, ARR.Latitude(1), ARR.Longitude(1));
ping_numbers = PING.Ping;
ping_times = datenum(PING.Date_Time_GMT);
expected_TDOA = nan(length(xsrc), Ntdoa);
for ipair = 1:Ntdoa
    r1 = sqrt((xsrc - receiverTable.("x [m]")(recPairs(ipair, 1))).^2 + (ysrc - receiverTable.("y [m]")(recPairs(ipair, 1))).^2);
    r2 = sqrt((xsrc - receiverTable.("x [m]")(recPairs(ipair, 2))).^2 + (ysrc - receiverTable.("y [m]")(recPairs(ipair, 2))).^2);
    expected_TDOA(:, ipair) = (r1-r2)./c;
end

expected_duration = 2*60;

fc = 38.5e3; % ping frequency [Hz]

b = fir1(16, (fc + [-5, 5]).*2/fs, 'bandpass');
a = 1;

%%
th = 10e-3;
TDOA = nan(10e3, 6);
TDet = nan(10e3, 1);
XAmp = TDOA;
label = TDet;
idet = 0;
for ip = 1:size(PING, 1)
    wav_directory = dir(['D:\OSA\Localization_Files\Pings\Ping*', num2str(PING.Ping(ip)), '*\*.wav']);

    % identify wav files containing time stamp
    wav_times = nan(numel(wav_directory), 1);
    for iw = 1:numel(wav_directory)
        wav_times(iw) = datenum(wav_directory(iw).name(3:end-4), 'yyyymmdd-HHMMSS');
    end

    startTime = ping_times(ip) - 3/(60*24);
    endTime = ping_times(ip) + 3/(60*24);

    [~, wav_file_idx] = min(abs(wav_times - ping_times(ip)));

    info = audioinfo(fullfile(wav_directory(wav_file_idx).folder, wav_directory(wav_file_idx).name));

    idxStart = max([1, round((ping_times(ip) - wav_times(wav_file_idx))*fs*spd)]);
    idxEnd = min([info.TotalSamples, idxStart + expected_duration*fs]);
    n1 = idxStart;
    n2 = n1 +4*fs;
    while n2<=idxEnd
        x = audioread(fullfile(wav_directory(wav_file_idx).folder, wav_directory(wav_file_idx).name), [n1, n2]);
        xf = filtfilt(b, a, x);

        if max(xf, [], 'all')>=th
            idet = idet+1;
            TDet(idet) = wav_times(wav_file_idx) + (n1+n2)/(2*spd*fs);
            label(idet) = ping_numbers(ip);
            [xc, lags] = xcov(xf, maxLags);

            for ixc = 1:Ntdoa
                %                 idxPos = find(abs(lags-expected_TDOA(ip, ixc))<.2*fs);
                [XAmp(idet, ixc), idxMax] = max(xc(:, indXcorr(ixc)));
                TDOA(idet, ixc) = lags(idxMax)/fs;
            end
        end

        n1 = n2+1;
        n2 = n1 + 4*fs;
    end

end

idxRem = find(isnan(TDet));
TDet(idxRem) = [];
TDOA(idxRem, :) = [];
XAmp(idxRem, :) = [];
label(idxRem) = [];

DET = table;
DET.TDet = TDet;
DET.TDOA = TDOA;
DET.XAmp = XAmp;
DET.label = label;
%%
% 20:27:20 - 20:28:27
fig = figure(22);
for sp = 1:size(TDOA, 2)
    subplot(3,2,sp)
    scatter(TDet, TDOA(:, sp), 11, XAmp(:, sp), 'filled')
    hold on
    scatter(ping_times, expected_TDOA(:,sp), 'rx')
    hold off
    datetick
end

fig = figure(23);
plot(receiverTable.("x [m]"), receiverTable.("y [m]"), 'ks')
hold on
plot(xsrc, ysrc, '.')
hold off

%%
ulab = unique(DET.label);
for ilab = 1:length(ulab)
    idx = find(DET.label==ulab(ilab));
    DET.label(idx) = ilab;
end
% brsh = gui.brushTDOA(DET);

%%

xmod = -4000:25:2000;
ymod = -3000:25:3000;

[X, Y] = meshgrid(xmod, ymod);
X = X(:);
Y = Y(:);
zmod = 10;
c = 1500;

mTDOA = zeros(length(X), Ntdoa);
i = 0;
for i1 = 1:size(receiverTable, 1)
    for i2 = (i1+1):size(receiverTable, 1)
        i = i+1;
        mTDOA(:, i) = -(sqrt((X-receiverTable.("x [m]")(i1)).^2 + (Y-receiverTable.("z [m]")(i1)).^2 + (zmod-receiverTable.("z [m]")(i1)).^2)./c ...
            - sqrt((X-receiverTable.("x [m]")(i2)).^2 + (Y-receiverTable.("z [m]")(i2)).^2 + (zmod-receiverTable.("z [m]")(i2)).^2)./c);
    end
end


%%
colors = [0, 0, 0; % unlabeled
    0.984314, 0.603922, 0.600000; % whale 1
    0.756863, 0.874510, 0.541176; % whale 2
    0.650980, 0.807843, 0.890196; % whale 3
    0.992157, 0.749020, 0.435294; % whale 4
    0.121569, 0.470588, 0.705882; % whale 5
    0.792157, 0.698039, 0.839216; % whale 6
    0.219608, 0.725490, 0.027451; % whale 7
    0.415686, 0.239216, 0.603922; % whale 8
    0.890196, 0.101961, 0.109804]; % whale 9

ulab = unique(DET.label);
fig = figure(99);
for ilab = 1:length(ulab)
    idx = find(DET.label==ulab(ilab));
    for i = 1:length(idx)
        numNotNan = sum(~isnan(DET.TDOA(idx(i), :)));
        err = sum((mTDOA - DET.TDOA(idx(i), :)).^2, 2, 'omitnan')./numNotNan;
        L = 1./err;
        [maxL, idxMax] = max(L);
        L = L./maxL;
        idx01 = find(L>.99);

        whale{ilab}.loc(i, :) = [X(idxMax), Y(idxMax), zmod];

        scatter(X(idxMax), Y(idxMax), [], colors(ilab, :), 'filled')
        hold on
    end
end
hold off