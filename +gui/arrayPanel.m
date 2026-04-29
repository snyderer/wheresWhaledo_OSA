classdef arrayPanel < handle
    properties
        wheresWhaledo
        panelHandle
        panelPosition

        loadConfigBtn
        setConfigBtn
        saveConfigBtn
        numberOfReceivers

        unitsTabGroup          % handle to tab group for meters/latlon
        metersTab              % handle to tab for meters
        latlonTab              % handle to tab for lat/lon

        receiverTableMeters     % meters table
        receiverTableLatLon     % lat/lon table

        gridOriginLatEdit
        gridOriginLonEdit
        params

        metersTable             % internal storage for meters data
    end

    methods
        function obj = arrayPanel(wheresWhaledo, panelPosition, params)
            obj.wheresWhaledo = wheresWhaledo;

            % Panel
            obj.panelHandle = uipanel('Parent', obj.wheresWhaledo.fig, ...
                'Title', '1. Set array configuration', 'FontSize', 14, ...
                'Position', panelPosition, 'BackgroundColor', params.colors.background);
            obj.panelPosition = panelPosition;
            obj.params.arrayTypes = {'1-ch (omni)'};

            % Load config button
            buttonPosition = [panelPosition(3)/2 - 120, panelPosition(4) - 50, 240, 20];
            obj.loadConfigBtn = uibutton('push', 'Parent', obj.panelHandle, ...
                'Text', 'load existing array configuration file', ...
                'Position', buttonPosition, 'FontSize', 12, ...
                'BackgroundColor', params.colors.items, ...
                'FontColor', params.colors.text, ...
                'ButtonPushedFcn', @obj.loadConfigFile);

            % Number of receivers
            recvY = panelPosition(4) - 90;
            uilabel('Parent', obj.panelHandle, 'Text', 'number of receivers:', ...
                'Position', [4, recvY, 140, 22], 'HorizontalAlignment', 'Right', ...
                'BackgroundColor', params.colors.background, ...
                'FontColor', params.colors.text);
            obj.numberOfReceivers = uieditfield(obj.panelHandle, 'numeric', ...
                'Position', [150, recvY, 30, 22], 'Value', 4, ...
                'ValueChangedFcn', @obj.changeNumberOfReceivers);

            % Grid origin label + inputs
            originY = recvY - 40;
            uilabel('Parent', obj.panelHandle, 'Text', 'Grid origin:', ...
                'Position', [150, originY, 80, 15], 'HorizontalAlignment', 'Right');

            % Label above lat/lon inputs
            uilabel('Parent', obj.panelHandle, 'Text', 'lat', ...
                'Position', [235, originY + 18, 60, 15], 'HorizontalAlignment', 'center');
            uilabel('Parent', obj.panelHandle, 'Text', 'lon', ...
                'Position', [300, originY + 18, 60, 15], 'HorizontalAlignment', 'center');

            obj.gridOriginLatEdit = uieditfield(obj.panelHandle, 'numeric', ...
                'Position', [235, originY, 60, 15], 'Tooltip', 'Latitude, decimal degrees');
            obj.gridOriginLonEdit = uieditfield(obj.panelHandle, 'numeric', ...
                'Position', [300, originY, 60, 15], 'Tooltip', 'Longitude, decimal degrees');

            % Units tab group
            tableY = originY - 260;
            obj.unitsTabGroup = uitabgroup('Parent', obj.panelHandle, ...
                'Position', [4, tableY, panelPosition(3)-8, 250]);

            % Meters tab
            obj.metersTab = uitab(obj.unitsTabGroup, 'Title', 'Meters');
            obj.receiverTableMeters = uitable('Parent', obj.metersTab, ...
                'Data', obj.buildTableData(4,'Meters'), ...
                'ColumnEditable', true, 'FontSize', 13, ...
                'Position', [10, 10, obj.unitsTabGroup.Position(3)-20, obj.unitsTabGroup.Position(4)-20]);

            % Lat/Lon tab
            obj.latlonTab = uitab(obj.unitsTabGroup, 'Title', 'Lat/Lon');
            obj.receiverTableLatLon = uitable('Parent', obj.latlonTab, ...
                'Data', obj.buildTableData(4,'LatLon'), ...
                'ColumnEditable', true, 'FontSize', 13, ...
                'Position', [10, 10, obj.unitsTabGroup.Position(3)-20, obj.unitsTabGroup.Position(4)-20]);

            % Set array config button
            setBtnY = 28;
            obj.setConfigBtn = uibutton('push', 'Parent', obj.panelHandle, ...
                'Text', 'set array configuration', ...
                'Position', [panelPosition(3)/2 - 120, setBtnY, 240, 20], ...
                'FontSize', 12, 'BackgroundColor', params.colors.items, ...
                'ButtonPushedFcn', @obj.setArrayConfiguration);

            % Save current config button
            saveBtnY = 4;
            obj.saveConfigBtn = uibutton('push', 'Parent', obj.panelHandle, ...
                'Text', 'save current array configuration', ...
                'Position', [panelPosition(3)/2 - 120, saveBtnY, 240, 20], ...
                'FontSize', 12, 'BackgroundColor', params.colors.items, ...
                'ButtonPushedFcn', @obj.saveConfigFile);
        end

        function data = buildTableData(obj, numReceivers, mode)
            hydNum = (1:numReceivers).';
            if strcmp(mode,'Meters')
                xloc = zeros(size(hydNum));
                yloc = xloc;
                zloc = xloc;
                data = table(hydNum, xloc, yloc, zloc, ...
                    'VariableNames', {'recNum','x_m','y_m','z_m'});
            else
                lat = zeros(size(hydNum));
                lon = lat;
                zloc = lat;
                data = table(hydNum, lat, lon, zloc, ...
                    'VariableNames', {'recNum','lat','lon','z_m'});
            end
        end

        %% callback functions
        function changeNumberOfReceivers(obj, ~, eventData)
            numReceivers = eventData.Value;
            % Rebuild both tables
            obj.receiverTableMeters.Data = obj.buildTableData(numReceivers,'Meters');
            obj.receiverTableLatLon.Data = obj.buildTableData(numReceivers,'LatLon');
        end

        function setArrayConfiguration(obj, ~, ~)
            activeTab = obj.unitsTabGroup.SelectedTab.Title;
            originLat = obj.gridOriginLatEdit.Value;
            originLon = obj.gridOriginLonEdit.Value;

            if strcmp(activeTab, 'Meters')
                % Get current meters data
                tblMeters = obj.receiverTableMeters.Data;
                tblMeters.z_m = -abs(tblMeters.z_m); % force negative depth

                % Convert meters to lat/lon and update Lat/Lon table
                tblLatLon = table(tblMeters.recNum, zeros(height(tblMeters),1), zeros(height(tblMeters),1), tblMeters.z_m, ...
                    'VariableNames', {'recNum','lat','lon','z_m'});
                for i = 1:height(tblMeters)
                    [lat, lon] = utils.xy2latlon(tblMeters.x_m(i), tblMeters.y_m(i), originLat, originLon);
                    tblLatLon.lat(i) = lat;
                    tblLatLon.lon(i) = lon;
                end
                obj.receiverTableLatLon.Data = tblLatLon;

                % Also store internal meters table for downstream use
                obj.metersTable = tblMeters;

            else % Lat/Lon tab active
                % Get current lat/lon data
                tblLatLon = obj.receiverTableLatLon.Data;
                tblLatLon.z_m = -abs(tblLatLon.z_m); % force negative depth

                % Convert lat/lon to meters and update Meters table
                tblMeters = table(tblLatLon.recNum, zeros(height(tblLatLon),1), zeros(height(tblLatLon),1), tblLatLon.z_m, ...
                    'VariableNames', {'recNum','x_m','y_m','z_m'});
                for i = 1:height(tblLatLon)
                    [x, y] = utils.latlon2xy(tblLatLon.lat(i), tblLatLon.lon(i), originLat, originLon);
                    tblMeters.x_m(i) = x;
                    tblMeters.y_m(i) = y;
                end
                obj.receiverTableMeters.Data = tblMeters;

                % Also store internal meters table for downstream use
                obj.metersTable = tblMeters;
            end
        end

        function loadConfigFile(obj, ~, ~)
            [file, location] = uigetfile('*.mat', 'Select array configuration file');
            if isequal(file,0) || isequal(location,0)
                fprintf('\ncanceled load\n')
            else
                tmp = load(fullfile(location, file));
                if isfield(tmp, 'receiverTable')
                    % Decide based on columns
                    if all(ismember({'x_m','y_m'}, tmp.receiverTable.Properties.VariableNames))
                        obj.receiverTableMeters.Data = tmp.receiverTable;
                        obj.unitsTabGroup.SelectedTab = obj.metersTab;
                    elseif all(ismember({'lat','lon'}, tmp.receiverTable.Properties.VariableNames))
                        obj.receiverTableLatLon.Data = tmp.receiverTable;
                        obj.unitsTabGroup.SelectedTab = obj.latlonTab;
                    else
                        fprintf('\nError: array configuration file is incorrect format\n')
                    end
                end
            end
            figure(obj.panelHandle.Parent)
        end

        function saveConfigFile(obj, ~, ~)
            [file, location] = uiputfile('*.mat', 'Select save location and file name', 'arrayTable');
            if isequal(file,0) || isequal(location,0)
                fprintf('\ncanceled save\n')
            else
                activeTab = obj.unitsTabGroup.SelectedTab.Title;
                if strcmp(activeTab,'Meters')
                    receiverTable = obj.receiverTableMeters.Data;
                else
                    receiverTable = obj.receiverTableLatLon.Data;
                end
                save(fullfile(location, file), 'receiverTable');
            end
        end
    end
end