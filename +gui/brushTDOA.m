classdef brushTDOA < handle
    properties
        data         % TDOA table
        fig          % figure handles
        plotHandles  % plot handles
        brushHandle  % brush handle
        controlPanel % control panel components
        plotPanel    % panel with plots
        legendBox    % legend box
        params       % general parameters, customizable by user
        state        % states and settings internal to the program. Not customizable. Change depending on how program is used.
        previousState = {};
        saveLoc
    end
    methods
        function obj = brushTDOA(data, params, saveLoc)
            if nargin==1 || isempty(params) % no user-provided params, set to default
                params.source = "default";
            else % override default with user-provided params
                params.source = "custom";
            end

            if nargin<3
                saveLoc = fullfile(pwd, 'brushedDET.mat');
            end

            obj.data = data;
            if sum(strcmp(obj.data.Properties.VariableNames, "label"))==0
                obj.data.label = zeros(height(obj.data), 1);
            end

            % determine if Brush TDOA figure is already open:
            isfig = findall(0, "Type", "figure", "name", "Brush TDOA");
            if isempty(isfig)
                obj.fig = figure("Name", "Brush TDOA");
            else
                close(isfig)
                obj.fig = figure("Name", "Brush TDOA");
            end

            obj.saveLoc = saveLoc;
            obj.setParams(params) % set params
            obj.state.numTDOA = size(obj.data.TDOA, 2);
            obj.state.plotOrder = 1:obj.state.numTDOA;
            obj.state.xlim = [min(obj.data.TDet)-10/8.64e4, max(obj.data.TDet)+10/8.64e4];
            obj.state.associated.toggle = false; % toggles on/off when the "associate data" command is run
            obj.buildGUI
        end
        %% initialization functions
        function buildGUI(obj)
            % build control panel:
            obj.buildControlPanel;
            obj.buildLegend;
            obj.setPlotPositions

            obj.brushHandle = brush(obj.fig);

            set(obj.brushHandle, 'Enable', 'on')

            % Get mode manager and current mode property to set keypress function
            hManager = uigetmodemanager(obj.fig);
            % Allows to change key press callback function
            [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2 (on 2014b or later)

            % Keypress Callback
            set(obj.fig, 'KeyPressFcn', @obj.keyPressCallback);

            % prepare previous save-states:
            for i = 1:obj.params.maxUndos
                obj.previousState(i).data = obj.data;
            end
        end

        function buildControlPanel(obj)
            % Builds the control panel
            obj.controlPanel = uipanel(obj.fig, "Title", "control panel", "BackgroundColor", [.91, .90, .84], ...
                "Units", "normalized", "Position", [.01, .8, .08, .19]);
            numTDOAs = size(obj.data.TDOA, 2);
            numRowsString = arrayfun(@num2str, 1:numTDOAs, "UniformOutput", false);
            numColsString = arrayfun(@num2str, 1:min([4, numTDOAs]), "UniformOutput", false);
            
            % determine number of rows/columns to display by default:
            if obj.state.numTDOA<=5 % fewer than 5 plots has 1 column
                obj.state.numCols = 1;
                obj.state.numRows = obj.state.numTDOA;
            elseif obj.state.numTDOA>5 && obj.state.numTDOA<=12
                obj.state.numCols = 2;
                obj.state.numRows = ceil(obj.state.numTDOA/2)
            else
                obj.state.numCols = 2;
                obj.state.numRows = 4;
            end

            % number of rows listbox:
            uicontrol(obj.controlPanel, "Style", "listbox", "String", numRowsString, ...
                "Units", "normalized", "Position", [.01, .01, .48, .89], "Value", obj.state.numRows, ...
                "Callback", @obj.numRowsCallback);
            uicontrol(obj.controlPanel, "Style", "text","String", "rows:", ...
                "Units", "normalized", "Position", [.01, .9, .48, .09])

            % number of columns listbox:
            uicontrol(obj.controlPanel, "Style", "listbox", "String", numColsString, ...
                "Units", "normalized", "Position", [.51, .01, .48, .89], "Value", obj.state.numCols, ...
                "Callback", @obj.numColsCallback);
            uicontrol(obj.controlPanel, "Style", "text","String", "columns:", ...
                "Units", "normalized", "Position", [.51, .9, .48, .09])
        end

        function buildLegend(obj)
            % make ui box for
            % set source labels:
            obj.legendBox = uipanel("Title", "commands", "BackgroundColor", [.91, .90, .84], ...
                "Units", "normalized", "Position", [.01, .01, .08, .78]);
            numLabels = size(obj.params.colors, 1);
            commands = {"[d]elete", "[a]ssociate", "[u]ndo", "[f]reehand"};
            numCommands = numel(commands);
            numButtons = numLabels + numCommands;
            yPositions = fliplr(0:1/numButtons:(1-1/numButtons));
            buttonHeight = 1/numButtons - .01;

            uicontrol(obj.legendBox, "Style", "pushbutton", "String", "[0] unlabeled", ...
                "Units", "normalized","Position", [0, yPositions(1), 1, buttonHeight], ...
                "BackgroundColor", obj.params.colors(1, :), "ForegroundColor", obj.params.buttonTextColors(1, :), ...
                "FontWeight", "bold","Callback", @obj.commandButtonCallback)

            for i = 2:numLabels
                labStr = sprintf("source [%d]", i-1);
                labCol = obj.params.colors(i, :);
                textCol = obj.params.buttonTextColors(i, :);
                uicontrol(obj.legendBox, "Style", "pushbutton", "String", labStr, ...
                    "Units", "normalized", "Position", [0, yPositions(i), 1, buttonHeight], ...
                    "BackgroundColor", labCol, "ForegroundColor", textCol, ...
                    "FontWeight", "bold", "Callback", @obj.commandButtonCallback)
            end
            for i = 1:numCommands
                uicontrol(obj.legendBox, "Style", "pushbutton", "String", commands{i}, ...
                    "Units", "normalized","Position", [0, yPositions(i+numLabels), 1, buttonHeight], ...
                    "BackgroundColor", [.82, .84, .82], "ForegroundColor", [.21, .11, .13], ...
                    "FontWeight", "bold","Callback", @obj.commandButtonCallback)
            end
        end

        function setPlotPositions(obj)
            % takes numRows and numCols and sets plot positions
            obj.plotPanel = uipanel(obj.fig, "BackgroundColor", [.91, .90, .84], ...
                "Units", "normalized", "Position", [.095, .005, .9, .99]);

            numRows = obj.state.numRows;
            numCols = obj.state.numCols;
            numPlots = min([numRows*numCols, obj.state.numTDOA]);

            % determine subplot locations:
            % Set the margin and width for the dropdowns
            dropdownWidth = obj.params.TDOAdropdownWidth; % Width of the dropdown menu
            marginX = obj.params.plotMargins(1); % Horizontal margin between plots
            marginY = obj.params.plotMargins(2); % Vertical margin between plots

            % Calculate the width and height of each plot
            plotWidth = (1 - (numCols + 1) * marginX - numCols * dropdownWidth) / numCols;
            plotHeight = (1 - (numRows + 1) * marginY) / numRows;

            % Loop through each position in the grid
            iplt = 0;
            for i = 1:numRows
                for j = 1:numCols
                    iplt = iplt+1;
                    tag = sprintf("p%02d", iplt);
                    if iplt>obj.state.numTDOA
                        break
                    end
                    % set drop-down menu:
                    dropdownXPos = marginX + (j-1)*(plotWidth + dropdownWidth + marginX);
                    yPos = 1-(i*(plotHeight + marginY));
                    uicontrol(obj.plotPanel, "Style", "popupmenu", "String", obj.params.TDOApairsString, "Value", obj.state.plotOrder(iplt), ...
                        "Units", "normalized", "Position", [dropdownXPos, yPos, dropdownWidth, plotHeight/3],...
                        "Callback", @(src, event) obj.tdoaDropDownCallback(src, event))

                    % set plot position:
                    plotXPos = dropdownXPos + dropdownWidth + marginX;
                    ax = axes(obj.plotPanel, "Units", "normalized", "Position", [plotXPos, yPos, plotWidth-.01, plotHeight]);

                    obj.setPlotData(ax, iplt)
                end
            end
        end

        function setPlotData(obj, axHandle, plotNum)
            tdoaNum = obj.state.plotOrder(plotNum);
            obj.plotHandles(plotNum) = scatter(axHandle, obj.data.TDet, obj.data.TDOA(:, tdoaNum), obj.params.markerSize, ...
                obj.params.colors(obj.data.label+1, :), "filled", "Tag", sprintf('p%02d_d%02d', plotNum, tdoaNum));
            xlim(obj.state.xlim)
            datetick("x", "keeplimits")
            title(sprintf("TDOA %s", obj.params.TDOApairsString{tdoaNum}))
        end

        function setParams(obj, params)
            % set default parameters, then override them with user-provided
            % parameters (if provided)

            % set figure position parameters (if user has not provided one)
            if isfield(params, "figPosition")
                obj.params.figPosition = params.figPosition;
                set(obj.fig, "Position", obj.params.figPosition)
            else
                % default figure position: screen size - toolbar:
                monitorPositions = get(0, "MonitorPositions"); % monitor positions
                [~, idxBiggestMonitor] = max((monitorPositions(:,3).*monitorPositions(:,4))); % determine which monitor is biggest

                obj.params.figPosition = monitorPositions(idxBiggestMonitor, :);
                set(obj.fig, "Position", obj.params.figPosition)

                obj.fig.WindowState = "maximized"; % maximize figure
                drawnow
                obj.params.figPosition = obj.fig.Position; % reset figure position
            end

            % set obj.params to default parameters:
            obj.params.markerSize = 5; % marker size for scatter points
            obj.params.displayLength = 60; % number of seconds to display
            obj.params.numTDOAs = size(obj.data.TDOA, 2); % total number of TDOAs
            obj.params.numReceivers = (1 + sqrt(1 + 8.*obj.params.numTDOAs))./2; % number of receivers
            obj.params.TDOApairs = nchoosek(1:obj.params.numReceivers, 2); % TDOA pair numbers:
            str = strsplit(sprintf('%d-%d\n', obj.params.TDOApairs.'));
            obj.params.TDOApairsString = str(1:obj.params.numTDOAs);
            obj.params.TDOAdropdownWidth = .03; % width of TDOA selection drop-down menu
            obj.params.plotMargins = [.02, .04]; % margins between plots
            obj.params.maxUndos = 5; % maximum number of undos allowed

            obj.params.colors = [0, 0, 0; % unlabeled
                0.984314, 0.603922, 0.600000; % whale 1
                0.756863, 0.874510, 0.541176; % whale 2
                0.650980, 0.807843, 0.890196; % whale 3
                0.992157, 0.749020, 0.435294; % whale 4
                0.121569, 0.470588, 0.705882; % whale 5
                0.792157, 0.698039, 0.839216; % whale 6
                0.219608, 0.725490, 0.027451; % whale 7
                0.415686, 0.239216, 0.603922; % whale 8
                0.890196, 0.101961, 0.109804]; % whale 9

            obj.params.buttonTextColors = repmat(1-median(round(obj.params.colors), 2), [1, 3]);
            % override default parameters with user-provided ones (if they exist)
            fldNames = fieldnames(params); % user-provided param names
            for nf = 1:numel(fldNames)
                obj.params.(fldNames{nf}) = params.(fldNames{nf});
            end
        end
        %% Functions to execute commands
        function assignLabels(obj, labelNumber)
            obj.state.associated.toggle = false;
            obj.storeBackup
            % assign label [labelNumber] to data and update plot colors
            ax = handle(obj.plotHandles);
            brshed = get(ax, "BrushData");
            idxSelected = [];
            for iax = 1:numel(brshed) % iterate through all axes
                idxSelected = [idxSelected, find(brshed{iax}~=0)];
            end
            idxSelected = unique(idxSelected);
            obj.data.label(idxSelected) = labelNumber;

            for iax = 1:numel(ax)
                set(ax(iax), 'CData', obj.params.colors(obj.data.label+1, :))
                set(ax(iax), 'BrushData', zeros(size(brshed{iax})))
            end
            DET = obj.data;
            save(obj.saveLoc, 'DET')
        end
        
        function runCommand(obj, command)
            switch command
                case 'a' % "associate" command: highlight the same detection on other plots
                    if obj.state.associated.toggle
                        % data have already been associated, undo association
                        ax = handle(obj.plotHandles);
                        for iax = 1:numel(ax)
                            brshed = zeros(size(ax(iax).BrushData));
                            idxSelected = obj.state.associated.idxSelected{iax};
                            brshed(idxSelected) = 1;
                            ax(iax).BrushData = brshed;
                        end
                        obj.state.associated.toggle = false; % flip the toggle back to false
                    else
                        % associate data across all displayed plots
                        ax = handle(obj.plotHandles);
                        brshed = get(ax, "BrushData");
                        idxSelectedAllPlots = [];
                        obj.state.associated.idxSelected = []; % stores the points which were initially selected (so they can be undone)
                        for iax = 1:numel(brshed) % iterate through all axes
                            idxSelected = find(brshed{iax}~=0);
                            obj.state.associated.idxSelected{iax} = idxSelected;
                            idxSelectedAllPlots = [idxSelectedAllPlots, idxSelected];
                        end
                        allBrushed = uint8(zeros(1, height(obj.data)));
                        allBrushed(idxSelectedAllPlots) = uint8(1);
                        for iax = 1:numel(ax)
                            %                         set(ax(iax), "BrushData", allBrushed)
                            ax(iax).BrushData = allBrushed;
                        end
                        obj.state.associated.toggle = true;
                    end
                case 'd' % delete
                    obj.storeBackup
                    obj.state.associated.toggle = false;
                    ax = handle(obj.plotHandles);
                    brshed = get(ax, "BrushData");
                    for iax = 1:numel(brshed) % iterate through all axes
                        idxSelectedAllPlots = find(brshed{iax}~=0);
                        tdoaNum = str2double(ax(iax).Tag(6:7));
                        obj.data.TDOA(idxSelectedAllPlots, tdoaNum) = nan;
                        set(ax(iax), 'XData', obj.data.TDet, 'YData', obj.data.TDOA(:, tdoaNum))
                        set(ax(iax), 'BrushData', zeros(size(brshed{iax})))
                    end
                case 'f' % freehand draw a line
                    obj.state.associated.toggle = false;
                    h = drawfreehand(obj.fig);
                case 'u' % undo
                    obj.state.associated.toggle = false;
                    tempData = obj.data;
                    obj.data = obj.previousState(1).data;
                    for i = 1:numel(obj.previousState)-1
                        obj.previousState(i).data = obj.previousState(i+1).data;
                    end
                    obj.previousState(end).data = tempData;
                    ax = handle(obj.plotHandles);
                    for iax = 1:numel(ax)
                        tdoaNum = str2double(ax(iax).Tag(6:7));
                        set(ax(iax), 'XData', obj.data.TDet, 'YData', obj.data.TDOA(:, tdoaNum), ...
                            'CData', obj.params.colors(obj.data.label+1, :));
                    end
            end
            DET = obj.data;
            save(obj.saveLoc, 'DET')
        end

        function storeBackup(obj)
            obj.previousState(1).data = obj.data;
            for i = 2:numel(obj.previousState)
                obj.previousState(i).data = obj.previousState(i-1).data;
            end
        end
        %% Callback functions
        function numRowsCallback(obj, ~, eventData)
            obj.state.numRows = eventData.Source.Value;
            obj.setPlotPositions
        end
        function numColsCallback(obj, ~, eventData)
            obj.state.numCols = eventData.Source.Value;
            obj.setPlotPositions
        end
        function tdoaDropDownCallback(obj, src, ~)
            tdoaNum = src.Value;
            plotNum = str2double(src.Tag(2:3));
            obj.state.plotOrder(plotNum) = tdoaNum;
            axHandle = obj.plotPanel.Children(end + 1 - plotNum); % find axes handle
            obj.setPlotData(axHandle, plotNum)
        end
        function commandButtonCallback(obj, src, ~)
            if contains(src.String, 'source') % assign label
                indNum = strfind(src.String, '[');
                labelNum = str2double(src.String(indNum+1));
                obj.assignLabels(labelNum)
            else
                indNum = strfind(src.String, '[');
                command = src.String(indNum+1);
                obj.runCommand(command)
            end
        end
        function keyPressCallback(obj, ~, eventData)
            if ~isnan(str2double(eventData.Character)) % number pressed
                obj.assignLabels(str2double(eventData.Character))
            else % letter key pressed
                obj.runCommand(eventData.Character)
            end
        end
    end
end