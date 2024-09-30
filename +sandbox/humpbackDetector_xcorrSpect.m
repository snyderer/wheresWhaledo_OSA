% Build spectrogram-based interface for selecting start/end times of calls
% on five channels?

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

% Nfft = 2048;

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
maxLag = ceil(maxTDOA*fs);

T = readtable('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\UID_06_Mn_Measurements.csv');
%%
tstart = datenum('05/04/2023 04:13:00'); % start time of test encounter
tend = tstart + 30/spd;

nstart = floor((tstart - fileStartTime)*spd*fs);
nend = floor((tend - fileStartTime)*spd*fs);

x = double(audioread(fileIn, [nstart, nend], 'native'));
t = (0:length(x)-1)./fs;

Noverlap = round(.5*maxLag);
Niter = round(length(x)/(maxLag-Noverlap));

XCS = nan(2*maxLag+1, Niter, Ntdoa);
ts = nan(Niter, 1);
n1 = 1;
n2 = n1 + maxLag - 1;
for i = 1:Niter
    ts(i) = t(n1);
    xSegment = x(n1:n2, :);
    xc = xcorr(xSegment, maxLag);
    xc = reshape(xc(:, indXcorr), 2*maxLag+1, 1, Ntdoa);
    XCS(:, i, :) = xc;
    n1 = n1 + maxLag - Noverlap;
    n2 = min([n1 + maxLag - 1, length(x)]);
end

%%
figure(2)
XCS(XCS<0) = 0;
for sp = 1:Ntdoa
    subplot(5,2,sp)
    imagesc(ts, (-maxLag:maxLag)./fs, 10.*log10(XCS(:, :, sp)))
    clim([50, 70])
    colorbar
    colormap jet
end

%%
Nfft = 1024;
f1 = min(T.freqBeg);
f2 = max(T.freqEnd);

f = 0:fs/Nfft:(fs-fs/Nfft);
w = 2*pi.*f;

indF = find(f>=f1 & f<=f2);

% XCS = nan(2*maxLag+1, Niter, Ntdoa);
ts = nan(Niter, 1);
n1 = 1;
n2 = n1 + maxLag - 1;
Xamp = nan(Niter, Ntdoa);
TDOA = Xamp;
iter = 1;
for i = 1:Niter
    ts(i) = t(n1);
    xSegment = x(n1:n2, :);
    X = fft(xSegment, Nfft);
    
    for ntdoa = 1:Ntdoa
        XC = X(indF, recPairs(ntdoa, 1)).*X(indF, recPairs(ntdoa, 2));
        [Xamp(i, ntdoa), Imax] = max(abs(XC));
        
        TDOA(i, ntdoa)= angle(XC(Imax))./w(indF(Imax));
        
    end

    n1 = n1 + maxLag - Noverlap;
    n2 = min([n1 + maxLag - 1, length(x)]);

end
%%

TDOA(Xamp<0.5e8) = nan;
figure(1)
for ntdoa = 1:Ntdoa
    subplot(5,2, ntdoa)
    scatter(ts, TDOA(:, ntdoa), 9, Xamp(:, ntdoa), 'filled')
end