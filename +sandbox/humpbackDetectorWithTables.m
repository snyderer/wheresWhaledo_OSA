% dep 1.1:
% fileIn = 'D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\M-20230504-041000.wav';
% T = readtable('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\UID_06_Mn_Measurements.xlsx');
% load('D:\OSA\wheresWhaledo_OSA\Dep1.1\arrayConfig.mat')

% dep 1.2:
fileIn = 'D:\OSA\Localization_Files\Dep1.2_Mn_UID05a\M-20230806-160000.wav';
T = readtable('D:\OSA\Localization_Files\Dep1.2_Mn_UID05a\Dep1.2_Mn_Example_UID05_Subset.csv');
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')

[fpath, fname] = fileparts(fileIn);
filenames = dir(fullfile(fpath, '*.wav'));
filenum = 1;
info = audioinfo(fileIn);
fs = info.SampleRate;
numRec = info.NumChannels;
% fileStartTime = datenum([2023 05 04 04 10 00]);
fileStartTime = datenum(fileIn(end-18:end-4), 'yyyymmdd-HHMMSS');

spd = 60*60*24;

Nfft = 2048;
win = kaiser(Nfft, 7.85);
Noverlap = round(Nfft*.95);

ixcov = 0;
itdoa = 0;
for i1 = 1:numRec
    for i2 = 1:numRec
        ixcov = ixcov+1;
        if i2>i1
            itdoa = itdoa+1;
            indXcorr(itdoa) = ixcov;
            recPairs(itdoa, :) = [i1, i2];
        end
    end
end

Ntdoa = length(indXcorr);
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')
hloc(:,1) = receiverTable.("x [m]");
hloc(:,2) = receiverTable.("y [m]");
hloc(:,3) = receiverTable.("z [m]");

maxTDOA = 2*max(sqrt(sum((hloc - hloc(1, :)).^2)))/1500 + .01;
maxLag = ceil(fs*maxTDOA);


[breject, areject] = butter(5, [1.7e3, 2.3e3].*2./fs, 'stop');

% TDOA_phase = nan(size(T, 1), Ntdoa);
% TDOA_GCC = nan(size(T, 1), Ntdoa);
TDOA = nan(size(T, 1), Ntdoa);
TDet = nan(size(T, 1), 1);
XAmp = TDOA;

for nt = 1:size(T, 1)

    f1 = max([T.freqMin(nt), 1]);
    f2 = min([T.freqMax(nt), fs/2]);

    b = fir1(7,unique([f1, f2]).*2./fs); a=1;

    TDet(nt) = datenum(T.UTC(nt));

    t1 = TDet(nt) - (T.duration(nt)+maxTDOA)/spd;
    t2 = t1 + (3*T.duration(nt)+maxTDOA)/spd;

    n1 = max([1, floor((t1-fileStartTime)*fs*spd)]);
    n2 = max([ceil((t2-fileStartTime)*fs*spd), n1+2*fs]);

    if n2>info.TotalSamples
        filenum = filenum + 1;
        fileIn = fullfile(filenames(filenum).folder, filenames(filenum).name);
        fileStartTime = datenum(fileIn(end-18:end-4), 'yyyymmdd-HHMMSS');
        n1 = max([1, floor((t1-fileStartTime)*fs*spd)]);
        n2 = max([ceil((t2-fileStartTime)*fs*spd), n1+2*fs]);
    end

    x = audioread(fileIn, [n1, n2]);
    xf = filtfilt(b, 1, x);
    xf = filtfilt(breject, areject, xf);
    [xc, lags] = xcov(xf, maxLag);
    X = fft(x);
    f = (0:length(X)-1).*fs/length(X);
    fidxRem = find(f>=235 & f<=238); % remove narrowband signal
    fidx = find(f>=floor(f1) & f<=floor(f2));
    for npair = 1:Ntdoa
%         R = X(:, recPairs(npair, 1)).*conj(X(:, recPairs(npair, 2)));
%         RGCC = R./abs(R);

        % remove constant ping:
%         RGCC(fidxRem) = 0;
%         xcGCC = ifft(RGCC, 'symmetric');
%         [~, pk] = max(xcGCC);
%         TDOA_GCC(nt, npair) = pk/fs;

%         TDOA_phase(nt, npair) = sum(angle(R(fidx)).'./(2*pi.*f(fidx)));

        [xcmax, imax] = max(xc(:, indXcorr(npair)));
        TDOA(nt, npair) = lags(imax)/fs;
        XAmp(nt, npair) = xcmax;
    end

    ok =1;
    if mod(nt, 100)==0
       ok = 1;
    end
    %     xf = filtfilt(b, a, x);
    %     [xc, lags] = xcov(xf);
    %     xc = xc(:, indXcorr);
    %     [maxXc, indMaxXc] = max(xc);
    %     XAmp(nt, :) = maxXc;
    %
    %     TDOA(nt, :) = lags(indMaxXc)./fs;
end

DET = table;
DET.TDOA = TDOA;
DET.TDet = TDet;
DET.XAmp = XAmp;

%%
figure(10)
for i = 1:Ntdoa
    subplot(ceil(Ntdoa/2),2,i)
    %     scatter(TDet, TDOA(:, i), 9, XAmp(:, i), "filled")
    %     plot(TDet, TDOA_GCC(:, i), "x")
    %     hold on
    %     plot(TDet, TDOA_phase(:, i), "x")
    plot(TDet, TDOA(:, i), '.')
    hold off
    datetick
    title(sprintf('%i - %i', recPairs(i, 1), recPairs(i, 2)))
end
% legend('GCC', 'Phase sum')