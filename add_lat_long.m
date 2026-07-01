% Script to load a CSV, ensure x_m and y_m, convert to lat/lon, and save table
% Prompts user to select CSV and to input grid origin (origin_lat, origin_lon)

% Select CSV file
[filename, pathname] = uigetfile({'*.csv','CSV files (*.csv)'}, 'Select CSV file');
if isequal(filename,0)
    error('No file selected.');
end
filepath = fullfile(pathname, filename);

% Read table
T = readtable(filepath);

% Check x_m exists
if ~ismember('x_m', T.Properties.VariableNames)
    error('Variable x_m not found in table.');
end

% Ensure y_m: if missing, compute from CI95_y_lo and CI95_y_hi
if ~ismember('y_m', T.Properties.VariableNames)
    if all(ismember({'CI95_y_lo','CI95_y_hi'}, T.Properties.VariableNames))
        T.y_m = (T.CI95_y_lo + T.CI95_y_hi) / 2;
    else
        error('y_m missing and CI95_y_lo/CI95_y_hi not available to compute it.');
    end
end

% Prompt for origin_lat and origin_lon via input dialog
dlgTitle = 'Grid origin (meters -> lat/lon)';
prompt = {'origin_lat (degrees):','origin_lon (degrees):'};
defaultAns = {'',''};
answer = inputdlg(prompt, dlgTitle, 1, defaultAns);
if isempty(answer)
    error('Origin input cancelled.');
end
origin_lat = str2double(answer{1});
origin_lon = str2double(answer{2});
if isnan(origin_lat) || isnan(origin_lon)
    error('Invalid origin values.');
end

% Compute lat/lon
[lat, lon] = utils.xy2latlon(T.x_m, T.y_m, origin_lat, origin_lon);

% Add or overwrite lat/lon in table
T.lat = lat;
T.lon = lon;

% Add date/time columns from TDet
if ~ismember('TDet', T.Properties.VariableNames)
    error('TDet not found in table.');
end
T.date = string(datestr(T.TDet, 'yyyy-MM-dd'));  % Month = 'MM'
T.time = string(datestr(T.TDet, 'HH:MM:SS.FFF'));

% Compute CI widths
if all(ismember({'CI95_x_hi','CI95_x_lo'}, T.Properties.VariableNames))
    T.CIx = max(abs([T.CI95_x_hi-T.x_m, T.CI95_x_lo-T.x_m]), [], 2);
end
if all(ismember({'CI95_y_hi','CI95_y_lo'}, T.Properties.VariableNames))
    T.CIy = max(abs([T.CI95_y_hi-T.y_m, T.CI95_y_lo-T.y_m]), [], 2);
end
if all(ismember({'CI95_z_hi','CI95_z_lo'}, T.Properties.VariableNames))
    T.CIz = max(abs([T.CI95_z_hi-T.z_m, T.CI95_z_lo-T.z_m]), [], 2);
end

%% --- Reorder columns ---
cols = T.Properties.VariableNames;

% Remove the ones we want to reposition from the list if they exist
moveAfterXYZ = {'lat','lon'};
moveAfterTDet = {'date','time'};
moveAfterCI95_z_hi = {'CIx', 'CIy', 'CIz'};


cols = setdiff(cols, [moveAfterXYZ, moveAfterTDet, moveAfterCI95_z_hi], 'stable');

% Insert lat/lon after z_m
idx_z = find(strcmp(cols,'z_m'));
if ~isempty(idx_z)
    moveAfterXYZExist = moveAfterXYZ(ismember(moveAfterXYZ, T.Properties.VariableNames));
    cols = [cols(1:idx_z), moveAfterXYZExist, cols(idx_z+1:end)];
end

% Insert date/time after TDet
idx_TDet = find(strcmp(cols,'TDet'));
if ~isempty(idx_TDet)
    moveAfterTDetExist = moveAfterTDet(ismember(moveAfterTDet, T.Properties.VariableNames));
    cols = [cols(1:idx_TDet), moveAfterTDetExist, cols(idx_TDet+1:end)];
end

% Insert CIx, CIy, CIz after CI95_z_hi
idx_ci = find(strcmp(cols,'CI95_z_hi'));
if ~isempty(idx_ci)
    moveAfterCIExist = moveAfterCI95_z_hi(ismember(moveAfterCI95_z_hi, T.Properties.VariableNames));
    cols = [cols(1:idx_ci), moveAfterCIExist, cols(idx_ci+1:end)];
end

% Apply new order
T = T(:, cols);

% Save table back to CSV (overwrite original)
writetable(T, filepath);

msgbox('CSV updated with lat/lon, date/time, CI widths, and reordered.', 'Done');