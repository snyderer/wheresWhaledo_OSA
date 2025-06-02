% load ping table:
PING = readtable('D:\OSA\Localization_Files\Pings\JJVessel_Pinger_Locations.csv');
PG = readtable('D:\OSA\Localization_Files\Pings\Pings_Dep1.2_10800.csv');
ARR = readtable('D:\OSA\Dep1.2_Recorder_Locations_Depths.csv');
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')

info = audioinfo('D:\OSA\Localization_Files\Pings\Ping7\M-20230808-193000.wav');
fs = info.SampleRate;
numRec = info.NumChannels;

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
uping = unique(ping_numbers);
for ipingNum = 1:length(ping_numbers)
    pingIdx(ipingNum) = find(ping_numbers(ipingNum)==uping);
end

ping_times = datenum(PING.Date_Time_GMT);
expected_TDOA = nan(length(xsrc), Ntdoa);
for ipair = 1:Ntdoa
    r1 = sqrt((xsrc - receiverTable.("x [m]")(recPairs(ipair, 1))).^2 + (ysrc - receiverTable.("y [m]")(recPairs(ipair, 1))).^2 + receiverTable.("z [m]")(recPairs(ipair, 1)));
    r2 = sqrt((xsrc - receiverTable.("x [m]")(recPairs(ipair, 2))).^2 + (ysrc - receiverTable.("y [m]")(recPairs(ipair, 2))).^2 + receiverTable.("z [m]")(recPairs(ipair, 2)));
    expected_TDOA(:, ipair) = (r2-r1)./c;
end
maxTDOA = 2*max(abs(expected_TDOA), [], 'all');
nmax = ceil(maxTDOA*fs);

figure(99); 
for sp = 1:6
    subplot(3,2,sp)
    scatter(ping_times, expected_TDOA(:, sp), [], colors(pingIdx, :), 'filled')
    datetick('x', 'mm/dd, HH:MM', 'keeplimits')
    title(sprintf('Pair %d-%d', recPairs(sp, :)))
end

%%
fc = 38.5e3; % ping frequency [Hz]
b = fir1(16, (fc + [-5, 5]).*2/fs, 'bandpass');
a = 1;


Ninit = 2e3;
DET = table;
DET.TDOA = nan(Ninit, 6);
DET.TDet = nan(Ninit, 1);
DET.XAmp = DET.TDOA;
DET.expTDOA = DET.TDOA;
DET.pingNumber = DET.TDet;

pgTimes = datenum(PG.UTC);
idet = 0;
for ipingNum = 1:length(uping)
    wav_directory = dir(['D:\OSA\Localization_Files\Pings\Ping*', num2str(uping(ipingNum)), '*\*.wav']);

    % identify wav files containing time stamp
    wav_start = nan(numel(wav_directory), 1);
    for iw = 1:numel(wav_directory)
        wav_start(iw) = datenum(wav_directory(iw).name(3:end-4), 'yyyymmdd-HHMMSS');
    end
    wav_end = wav_start + 10/(60*24);
    
    for iw = 1:length(wav_start)
        info = audioinfo(fullfile(wav_directory(iw).folder, wav_directory(iw).name));
        idxPings = find(pgTimes>=wav_start(iw) & pgTimes<=wav_end(iw));
        
        for ip = 1:length(idxPings)
            idet = idet+1;
            
            [~, currentPingIdx] = min(abs(ping_times - pgTimes(idxPings(ip))));
            DET.pingNumber(idet) = ping_times(currentPingIdx);
            DET.TDet(idet) = pgTimes(idxPings(ip));

            n1 = max([1, round((pgTimes(idxPings(ip)) -  wav_start(iw))*spd*fs - nmax)]);
            n2 = min([round(n1 + 2*nmax), info.TotalSamples]);

            x = audioread(fullfile(wav_directory(iw).folder, wav_directory(iw).name), [n1, n2]);
            xf = filter(b, a, x);

            for itdoa = 1:Ntdoa
                [xc, lags] = xcov(xf(:, recPairs(itdoa, 1)), xf(:, recPairs(itdoa, 2)), nmax);
                                
                DET.expTDOA(idet, itdoa) = expected_TDOA(currentPingIdx, itdoa);
                
                [pks, locs] = findpeaks(xc, 'MinPeakDistance', .5*fs, 'NPeaks', 4);
                
                % take peak closest to expected TDOA:
                [~, tmp] = min(abs(lags(locs)-DET.expTDOA(idet, itdoa)));
                DET.TDOA(idet, itdoa) = lags(locs(tmp))./fs;
                DET.XAmp(idet, itdoa) = pks(tmp);
            end
            
        end
    end
end
DET(idet+1:end, :) = [];

%%
tdoaSign = [1, 1, 1, 1, 1, 1]
figure(60)
for sp =1:6
    subplot(3,2,sp)
plot(DET.TDet, tdoaSign(sp).*DET.TDOA(:, sp), '.')
hold on
plot(DET.TDet, -DET.expTDOA(:, sp), 'x')
hold off
end
%%
xmod = -5000:25:5000;
ymod = -5000:25:5000;

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
        mTDOA(:, i) = (sqrt((X-receiverTable.("x [m]")(i1)).^2 + (Y-receiverTable.("y [m]")(i1)).^2 + (zmod-receiverTable.("z [m]")(i1)).^2)./c ...
            - sqrt((X-receiverTable.("x [m]")(i2)).^2 + (Y-receiverTable.("y [m]")(i2)).^2 + (zmod-receiverTable.("z [m]")(i2)).^2)./c);
    end
end

%%
brsh = gui.brushTDOA(DET);
%%
DET.loc = nan(height(DET), 3);
for idet = 1:height(DET)
    err = sum((mTDOA - DET.TDOA(idet, :)).^2, 2);
    L = 1./err;
    [Lmax, idxMax] = max(L);
    
    DET.loc(idet, :) = [X(idxMax), Y(idxMax), zmod];
    
end
%%
figure(48)
plot(DET.loc(:, 1), DET.loc(:,2), '.')
hold on
plot(xsrc, ysrc, 'x')
hold off        