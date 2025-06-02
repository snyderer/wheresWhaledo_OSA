function T = whaleStruct2Table(whale, saveloc, lat0, lon0)
if nargin<2
    saveflag = false;
else
    saveflag = true;
end

numWhales = numel(whale);

for iw = 1:numWhales
    T{iw} = table;
    T{iw}.TDet = whale{iw}.TDet;
    T{iw}.date = datestr(whale{iw}.TDet, 'yy-mmm-dd');
    T{iw}.time = datestr(whale{iw}.TDet, 'HH:MM:SS.FFF');
    T{iw}.loc_x = whale{iw}.loc(:, 1);
    T{iw}.loc_y = whale{iw}.loc(:, 2);
    T{iw}.loc_z = whale{iw}.loc(:, 3);
    T{iw}.CI95_x_low = whale{iw}.CI95_x(:, 1);
    T{iw}.CI95_x_hi = whale{iw}.CI95_x(:, 2);
    T{iw}.CI95_y_low = whale{iw}.CI95_y(:, 1);
    T{iw}.CI95_y_hi = whale{iw}.CI95_y(:, 2);
    T{iw}.CI95_z_low = whale{iw}.CI95_z(:, 1);
    T{iw}.CI95_z_hi = whale{iw}.CI95_z(:, 2);

    if nargin==4
        [T{iw}.lat, T{iw}.lon] = utils.xy2latlon(T{iw}.loc_x, T{iw}.loc_y, lat0, lon0);
    end

    if saveflag
        DATA = T{iw};
        writetable(DATA, sprintf('%s_whale%i.csv', saveloc, iw))
    end
end

end