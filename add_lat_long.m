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

% Call utils.xy2latlon to compute lat/lon
% Expecting function signature: [lat, lon] = utils.xy2latlon(x_m, y_m, origin_lat, origin_lon)
[lat, lon] = utils.xy2latlon(T.x_m, T.y_m, origin_lat, origin_lon);

% Add or overwrite lat/lon in table
T.lat = lat;
T.lon = lon;

% Save table back to CSV (overwrite original)
writetable(T, filepath);

msgbox('CSV updated with lat/lon and saved.', 'Done');