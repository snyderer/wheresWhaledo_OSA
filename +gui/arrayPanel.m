classdef arrayPanel < handle
    properties
        wheresWhaledo
        panelHandle
        panelPosition

        loadConfigBtn
        setConfigBtn
        saveConfigBtn
        numberOfReceivers
        useRec1Check

        unitsTabGroup
        metersTab
        latlonTab

        receiverTableMeters
        receiverTableLatLon

        gridOriginLatEdit
        gridOriginLonEdit
        params

        metersTable
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

            % Checkbox next to origin label
            obj.useRec1Check = uicheckbox('Parent', obj.panelHandle, ...
                'Text', 'use rec 1 as origin', ...
                'Value', true, ...
                'Position', [20, originY, 120, 15], ...
                'ValueChangedFcn', @(src,~)obj.toggleOriginFields());

            % Labels
            uilabel('Parent', obj.panelHandle, 'Text', 'origin lat:', ...
                'Position', [160, originY + 18, 90, 15], 'HorizontalAlignment', 'center');
            uilabel('Parent', obj.panelHandle, 'Text', 'origin lon:', ...
                'Position', [260, originY + 18, 90, 15], 'HorizontalAlignment', 'center');

            % Origin edit fields with listeners
            obj.gridOriginLatEdit = uieditfield(obj.panelHandle, 'numeric', ...
                'Position', [160, originY, 90, 15], ...
                'Tooltip', 'Latitude, decimal degrees', ...
                'ValueDisplayFormat', '%.6f', 'Enable', 'off');
            obj.gridOriginLonEdit = uieditfield(obj.panelHandle, 'numeric', ...
                'Position', [260, originY, 90, 15], ...
                'Tooltip', 'Longitude, decimal degrees', ...
                'ValueDisplayFormat', '%.6f', 'Enable', 'off');

            % Update appropriate table based on active tab when origin changes
            obj.gridOriginLatEdit.ValueChangedFcn = @(src,~)obj.updateBasedOnActiveTab();
            obj.gridOriginLonEdit.ValueChangedFcn = @(src,~)obj.updateBasedOnActiveTab();

            % Units tab group
            tableY = originY - 260;
            obj.unitsTabGroup = uitabgroup('Parent', obj.panelHandle, ...
                'Position', [4, tableY, panelPosition(3)-8, 250]);

            % Meters tab
            obj.metersTab = uitab(obj.unitsTabGroup, 'Title', 'Meters');
            obj.receiverTableMeters = uitable('Parent', obj.metersTab, ...
                'Data', obj.buildTableData(4,'Meters'), ...
                'ColumnEditable', true, 'FontSize', 13, ...
                'Position', [10, 10, obj.unitsTabGroup.Position(3)-20, obj.unitsTabGroup.Position(4)-36]);

            % When meters table is edited, update lat/lon
            obj.receiverTableMeters.CellEditCallback = @(tbl,eventData)obj.onMetersTableEdit(eventData);

            % Lat/Lon tab
            obj.latlonTab = uitab(obj.unitsTabGroup, 'Title', 'Lat/Lon');
            obj.receiverTableLatLon = uitable('Parent', obj.latlonTab, ...
                'Data', obj.buildTableData(4,'LatLon'), ...
                'ColumnEditable', true, 'FontSize', 13, ...
                'Position', [10, 10, obj.unitsTabGroup.Position(3)-20, obj.unitsTabGroup.Position(4)-36]);

            % When lat/lon table is edited, update meters
            obj.receiverTableLatLon.CellEditCallback = @(tbl,eventData)obj.onLatLonTableEdit(eventData);

            % Set array config buton
            setBtnY = 28;
            obj.setConfigBtn = uibutton('push', 'Parent', obj.panelHandle, ...
                'Text', 'set array configuration', ...
                'Position', [panelPosition(3)/2 - 120, setBtnY, 240, 20], ...
                'FontSize', 12, 'BackgroundColor', params.colors.items, ...
                'ButtonPushedFcn', @obj.setArrayConfiguration);

            % Save config button
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
                data = table(hydNum, zeros(size(hydNum)), zeros(size(hydNum)), zeros(size(hydNum)), ...
                    'VariableNames', {'recNum','x_m','y_m','z_m'});
            else
                data = table(hydNum, zeros(size(hydNum)), zeros(size(hydNum)), zeros(size(hydNum)), ...
                    'VariableNames', {'recNum','lat','lon','z_m'});
            end
        end

        %% Lat/lon/meters Update Helpers
        function updateBasedOnActiveTab(obj)
            % Update the appropriate table based on which tab is currently active
            activeTab = obj.unitsTabGroup.SelectedTab.Title;
            if strcmp(activeTab, 'Meters')
                % Meters tab is active, so update lat/lon from meters
                obj.updateLatLonFromMeters();
            else
                % Lat/lon tab is active, so update meters from lat/lon
                obj.updateMetersFromLatLon();
            end
        end

        function updateMetersFromLatLon(obj)
            originLat = obj.gridOriginLatEdit.Value;
            originLon = obj.gridOriginLonEdit.Value;
            tblLatLon = obj.receiverTableLatLon.Data;
            tblMeters = table(tblLatLon.recNum, zeros(height(tblLatLon),1), zeros(height(tblLatLon),1), tblLatLon.z_m, ...
                'VariableNames', {'recNum','x_m','y_m','z_m'});
            for i = 1:height(tblLatLon)
                [x, y] = utils.latlon2xy(tblLatLon.lat(i), tblLatLon.lon(i), originLat, originLon);
                tblMeters.x_m(i) = x;
                tblMeters.y_m(i) = y;
            end
            obj.receiverTableMeters.Data = tblMeters;
            obj.metersTable = tblMeters;
        end

        function updateLatLonFromMeters(obj)
            originLat = obj.gridOriginLatEdit.Value;
            originLon = obj.gridOriginLonEdit.Value;
            tblMeters = obj.receiverTableMeters.Data;
            tblLatLon = table(tblMeters.recNum, zeros(height(tblMeters),1), zeros(height(tblMeters),1), tblMeters.z_m, ...
                'VariableNames', {'recNum','lat','lon','z_m'});
            for i = 1:height(tblMeters)
                [lat, lon] = utils.xy2latlon(tblMeters.x_m(i), tblMeters.y_m(i), originLat, originLon);
                tblLatLon.lat(i) = lat;
                tblLatLon.lon(i) = lon;
            end
            obj.receiverTableLatLon.Data = tblLatLon;
        end


        function updateOriginFromRec1(obj)
            if ~obj.useRec1Check.Value
                return;
            end

            activeTab = obj.unitsTabGroup.SelectedTab.Title;
            if strcmp(activeTab, 'Meters')
                % If we're on the meters tab, get rec 1 from meters table
                tblMeters = obj.receiverTableMeters.Data;
                rec1 = tblMeters(tblMeters.recNum == 1, :);
                if ~isempty(rec1)
                    % Convert rec 1's current position to lat/lon using current origin
                    [lat, lon] = utils.xy2latlon(rec1.x_m, rec1.y_m, ...
                        obj.gridOriginLatEdit.Value, obj.gridOriginLonEdit.Value);
                    obj.gridOriginLatEdit.Value = lat;
                    obj.gridOriginLonEdit.Value = lon;
                end
            else
                % If we're on the lat/lon tab, get rec 1 from lat/lon table
                tblLatLon = obj.receiverTableLatLon.Data;
                rec1 = tblLatLon(tblLatLon.recNum == 1, :);
                if ~isempty(rec1)
                    obj.gridOriginLatEdit.Value = rec1.lat;
                    obj.gridOriginLonEdit.Value = rec1.lon;
                end
            end
        end
        %% Callbacks
        function changeNumberOfReceivers(obj, ~, eventData)
            numReceivers = eventData.Value;
            obj.receiverTableMeters.Data = obj.buildTableData(numReceivers,'Meters');
            obj.receiverTableLatLon.Data = obj.buildTableData(numReceivers,'LatLon');
        end

        function toggleOriginFields(obj)
            if obj.useRec1Check.Value
                obj.gridOriginLatEdit.Enable = 'off';
                obj.gridOriginLonEdit.Enable = 'off';
                obj.updateOriginFromRec1();
            else
                obj.gridOriginLatEdit.Enable = 'on';
                obj.gridOriginLonEdit.Enable = 'on';
            end
            %  always update meters after origin toggle
            obj.updateBasedOnActiveTab();
        end

        function setArrayConfiguration(obj, ~, ~)
            %  Sync both tables before committing
            obj.updateMetersFromLatLon();
            obj.updateLatLonFromMeters();
            obj.metersTable = obj.receiverTableMeters.Data;
        end

        function onMetersTableEdit(obj, eventData)
            % If use rec 1 as origin is checked and user tries to edit rec 1's x or y position
            if obj.useRec1Check.Value && eventData.Indices(1) == 1 && (eventData.Indices(2) == 2 || eventData.Indices(2) == 3)
                % Reset rec 1's x and y to 0,0 (columns 2 and 3 are x_m and y_m)
                tblData = obj.receiverTableMeters.Data;
                tblData.x_m(1) = 0;
                tblData.y_m(1) = 0;
                obj.receiverTableMeters.Data = tblData;

                % Update lat/lon table
                obj.updateLatLonFromMeters();
                return;  % Don't process further
            end

            % Check if receiver 1 was edited and checkbox is checked (for z position or other edits)
            if obj.useRec1Check.Value && eventData.Indices(1) == 1 && eventData.Indices(2) > 1
                % Receiver 1's position was edited, update origin
                obj.updateOriginFromRec1();
            end

            % Always update the other table
            obj.updateLatLonFromMeters();
        end

        function onLatLonTableEdit(obj, eventData)
            % Check if receiver 1 was edited and checkbox is checked
            if obj.useRec1Check.Value && eventData.Indices(1) == 1 && eventData.Indices(2) > 1
                % Receiver 1's position was edited, update origin
                obj.updateOriginFromRec1();
            end
            % update the other table
            obj.updateMetersFromLatLon();
        end

        %% Load / Save
        function loadConfigFile(obj, ~, ~)
            [file, location] = uigetfile('*.mat', 'Select array configuration file', obj.wheresWhaledo.lastFilePath);
            if isequal(file,0) || isequal(location,0)
                fprintf('\ncanceled load\n')
                return
            end
            obj.wheresWhaledo.lastFilePath = location;
            tmp = load(fullfile(location, file));
            if ~isfield(tmp, 'combinedTbl')
                fprintf('\nError: configuration missing combinedTbl\n');
                return
            end
            combinedTbl = tmp.combinedTbl;
            metersTbl = table(combinedTbl.recNum, combinedTbl.x_m, combinedTbl.y_m, combinedTbl.z_m, ...
                'VariableNames', {'recNum','x_m','y_m','z_m'});
            obj.receiverTableMeters.Data = metersTbl;
            latlonTbl = table(combinedTbl.recNum, combinedTbl.lat, combinedTbl.lon, combinedTbl.z_m, ...
                'VariableNames', {'recNum','lat','lon','z_m'});
            obj.receiverTableLatLon.Data = latlonTbl;
            if isfield(tmp, 'gridOriginLat'), obj.gridOriginLatEdit.Value = tmp.gridOriginLat; end
            if isfield(tmp, 'gridOriginLon'), obj.gridOriginLonEdit.Value = tmp.gridOriginLon; end
            obj.numberOfReceivers.Value = height(obj.receiverTableMeters.Data);
            obj.metersTable = metersTbl;
        end

        function saveConfigFile(obj, ~, ~)
            [file, location] = uiputfile('*.mat', 'Save array configuration', ...
                fullfile(obj.wheresWhaledo.lastFilePath, 'arrayTable'));
            if isequal(file,0) || isequal(location,0)
                fprintf('\ncanceled save\n')
                return
            end
            obj.wheresWhaledo.lastFilePath = location;
            metersTbl = obj.receiverTableMeters.Data;
            latlonTbl = obj.receiverTableLatLon.Data;
            combinedTbl = table(metersTbl.recNum, metersTbl.x_m, metersTbl.y_m, metersTbl.z_m, ...
                latlonTbl.lat, latlonTbl.lon, ...
                'VariableNames', {'recNum','x_m','y_m','z_m','lat','lon'});
            gridOriginLat = obj.gridOriginLatEdit.Value;
            gridOriginLon = obj.gridOriginLonEdit.Value;
            save(fullfile(location, file), 'combinedTbl', 'gridOriginLat', 'gridOriginLon');
        end
    end
end