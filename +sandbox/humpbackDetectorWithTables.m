%% TO DO NEXT:
% adapt so it calculates the spectrogram

fileIn = 'D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\M-20230504-041000.wav';
info = audioinfo(fileIn);
fs = info.SampleRate;
numRec = info.NumChannels;
fileStartTime = datenum([2023 05 04 04 10 00]);

spd = 60*60*24;

hydLatLon = [36.79643,	-121.85043;
    36.79487,	-121.84875;
    36.79497,	-121.85202;
    36.79827,	-121.85168;
    36.79802,	-121.84809];

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

h0 = hydLatLon(1, :); % center hydrophone is 0,0
[hloc(:,1), hloc(:,2)] = utils.latlon2xy(hydLatLon(:,1), hydLatLon(:,2), h0(1), h0(2));

hloc(:,3) = -[233, 246, 238, 251, 229].';

maxTDOA = max(sqrt(sum((hloc - hloc(1, :)).^2)))/1500 + .01;

T = readtable('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\UID_06_Mn_Measurements.csv');

TDOA = nan(size(T, 1), Ntdoa);
TDet = nan(size(T, 1), 1);
XAmp = TDOA;
%%
    f1 = min(T.freqBeg);
    f2 = max(T.freqEnd(nt));

%     [b, a] = butter(5, [f1, f2].*2./fs);
    b = fir1(5,[f1, f2].*2./fs); a=1;


for nt = 1:size(T, 1)

    TDet(nt) = datenum(T.UTC(nt));

    t1 = TDet(nt) - (T.duration(nt)+maxTDOA)/spd;
    t2 = t1 + (2*T.duration(nt)+maxTDOA)/spd;

    n1 = floor((t1-fileStartTime)*fs*spd);
    n2 = ceil((t2-fileStartTime)*fs*spd);
    
    if n1<1 
        continue
    end
    if n2>info.TotalSamples
        break
    end

    x = audioread(fileIn, [n1, n2]);

    for ns = 1:numRec
        [~, f, t, PS{ns}] = spectrogram(x(:,ns), win, Noverlap, Nfft, fs);

        indF = find(f>=f1 & f<=f2)
        figure(100)
        subplot(numRec, 1, ns);
        imagesc(t, f(indF), 10.*log10(PS{ns}(indF, :)))
        colorbar
        clim([-100, -80])
        set(gca, 'YDir', 'normal')
    end

    pause
%     xf = filtfilt(b, a, x);
%     [xc, lags] = xcov(xf);
%     xc = xc(:, indXcorr);
%     [maxXc, indMaxXc] = max(xc);
%     XAmp(nt, :) = maxXc;
% 
%     TDOA(nt, :) = lags(indMaxXc)./fs;
end

%%
figure(1)
for i = 1:Ntdoa
    subplot(5,2,i)
    scatter(TDet, TDOA(:, i), 9, XAmp(:, i), "filled")
    datetick
end