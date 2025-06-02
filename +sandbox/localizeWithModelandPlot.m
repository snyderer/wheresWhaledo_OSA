% load('D:\OSA\wheresWhaledo_OSA\Dep1.1\arrayConfig.mat.mat')
% load('D:\OSA\Localization_Files\Dep1.1_LF_UID06_Mn\brushed.mat')

load('D:\OSA\Localization_Files\Dep1.2_Mn_UID05a\brushed.mat')
load('D:\OSA\wheresWhaledo_OSA\Dep1.2\arrayConfig.mat')
vidFilePathName = 'D:\OSA\wheresWhaledo_OSA\Dep1.2\MN05.mp4';

% interpFlag = true;
interpFlag = false;
plotFlag = true;

sightingLoc = [-3.3111e3, 995.34];

sigma = sqrt(2*(10^2)/1500^2 + .001^2);

numTDOA = size(DET.TDOA, 2);
%% make model:

xmod = -3000:5:2000;
ymod = -3000:5:2000;
zmod = 10;
[X, Y, Z] = meshgrid(xmod, ymod, zmod);
X = X(:);
Y = Y(:);
Z = Z(:);
c = 1480;

mTDOA = zeros(length(X), numTDOA);
i = 0;
for i1 = 1:size(receiverTable, 1)
    for i2 = (i1+1):size(receiverTable, 1)
        i = i+1;
        mTDOA(:, i) = (sqrt((X-receiverTable.("x [m]")(i1)).^2 + (Y-receiverTable.("y [m]")(i1)).^2 + (Z-receiverTable.("z [m]")(i1)).^2)./c ...
            - sqrt((X-receiverTable.("x [m]")(i2)).^2 + (Y-receiverTable.("y [m]")(i2)).^2 + (Z-receiverTable.("z [m]")(i2)).^2)./c);
    end
end


DET = sortrows(DET, 'TDet');
idxRem = find(sum(~isnan(DET.TDOA), 2)<3);
DET(idxRem, :) = [];

[~, idxUnique] = unique(DET.TDet);
DET = DET(idxUnique, :);

whaleNums = unique(DET.label);


for iwhale = 1:length(whaleNums)
    idxWhale = find(DET.label==whaleNums(iwhale));
    whale{iwhale} = table;
    whale{iwhale}.TDet = DET.TDet(idxWhale);
    whale{iwhale}.loc = nan(length(idxWhale), 3);
    whale{iwhale}.CI95_x = nan(length(idxWhale), 2);
    whale{iwhale}.CI95_y = nan(length(idxWhale), 2);
    whale{iwhale}.CI95_z = nan(length(idxWhale), 2);

    whale{iwhale}.CI75_x = nan(length(idxWhale), 2);
    whale{iwhale}.CI75_y = nan(length(idxWhale), 2);
    whale{iwhale}.CI75_z = nan(length(idxWhale), 2);

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
%     t = DET.TDet(idxWhale(idxStart)):(1/(60*60*24)):whale{iwhale}.TDet(idxWhale(idxEnd));
%     tdoai = interp1(DET.TDet(idxWhale), tdoa, t);
%     tdoai = movmedian(tdoai, 30);
tdoai = tdoa;
    if plotFlag
        vidfile = VideoWriter(vidFilePathName,'MPEG-4');
        open(vidfile);
    end
    for i = 1:length(tdoai)
        numNotNan = sum(~isnan(tdoai(i, :)));
        
        err = sum((mTDOA - tdoai(i, :)).^2, 2, 'omitnan')./numNotNan;
        L = 1/(2*pi*sigma^2)^numNotNan * exp(-1/(2*sigma^2).*err);
        [maxL, idxMax] = max(L);
       
        whale{iwhale}.loc(i, :) = [X(idxMax), Y(idxMax), Z(idxMax)];

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

        whale{iwhale}.CI95_x(i, 1) = max([xmod(Cx<=.025), nan]);
        whale{iwhale}.CI95_x(i, 2) = min([xmod(Cx>=.975), nan]);
        whale{iwhale}.CI95_y(i, 1) = max([ymod(Cy<=.025), nan]);
        whale{iwhale}.CI95_y(i, 2) = min([ymod(Cy>=.975), nan]);
        whale{iwhale}.CI95_z(i, 1) = max([zmod(Cz<=.025), nan]);
        whale{iwhale}.CI95_z(i, 2) = min([zmod(Cz>=.975), nan]);

%         whale{iwhale}.CI75_x(i, 1) = max([xmod(Cx<=.075), nan]);
%         whale{iwhale}.CI75_x(i, 2) = min([xmod(Cx>=.925), nan]);
%         whale{iwhale}.CI75_y(i, 1) = max([ymod(Cy<=.075), nan]);
%         whale{iwhale}.CI75_y(i, 2) = min([ymod(Cy>=.925), nan]);
%         whale{iwhale}.CI75_z(i, 1) = max([zmod(Cz<=.075), nan]);
%         whale{iwhale}.CI75_z(i, 2) = min([zmod(Cz>=.925), nan]);
 
    end

end


if plotFlag

    close(vidfile)
end