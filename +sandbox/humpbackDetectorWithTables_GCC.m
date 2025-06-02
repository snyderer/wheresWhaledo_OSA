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
maxLag = ceil(2*maxTDOA*fs);

T = readtable('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\UID_06_Mn_Measurements.xlsx');

TDOA = nan(size(T, 1), Ntdoa);
TDet = datenum(T.UTC);
XAmp = TDOA;
%% Build reference signal 

iter = 0;
twin = 8; % time window
Nwin = twin*fs;
Nfft = Nwin;

f = (0:Nfft).*fs/Nfft;

fstart = T.freqMin;
fend = T.freqMax;
% fstart = 10;
% fend = 1900;
f1 = min(fstart);
f2 = max(fend);

IdxPassband = find((f>=f1 & f<=f2) | (f>=(fs-f2) & f<=(fs-f1)));
% IdxPassband = 1:12e3;
IdxRejectband = 1:length(f);
IdxRejectband(IdxPassband) = [];
%     [b, a] = butter(5, [f1, f2].*2./fs);
b = fir1(5,[f1, f2].*2./fs); a=1;

Ishift = [Nwin/2+1:Nwin, 1:Nwin/2];

for nt = 1:size(T, 1)
    
    t1 = TDet(nt) - twin/spd;

    n1 = floor((t1-fileStartTime)*fs*spd);
    n2 = n1 + Nwin-1;
    
    if n1<1 
        continue
    end
    if n2>info.TotalSamples
        break
    end

    x = audioread(fileIn, [n1, n2]);
    X = fft(x);
    xc = nan(length(x), Ntdoa);
    for ntdoa = 1:Ntdoa
        Rxy = (X(:, recPairs(ntdoa, 1)).*conj(X(:, recPairs(ntdoa, 2))));
        wts = abs(R);
        wts(IdxRejectband) = 0;
        xc(:, ntdoa) = ifft(Rxy.*wts);
    end
    xc = xc(Ishift, :);
    [maxXc, indMaxXc] = max(xc);
%     figure(1); plot(xc)
    XAmp(nt, :) = maxXc;

    TDOA(nt, :) = lags(indMaxXc)./fs;
end

%%
figure(1)
for i = 1:Ntdoa
    subplot(5,2,i)
    scatter(TDet, TDOA(:, i), 9, XAmp(:, i), "filled")
    datetick
end