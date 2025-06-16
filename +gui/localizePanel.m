classdef localizePanel < handle
    properties
        % handles:
        wheresWhaledo
        panelHandle

        localizer       % handle of selected localizer

        loadConfigButtonHandle
        saveConfigButtonHandle

        selectModelLocationButtonHandle
        saveModelBoxHandle
        selectLocalizationsLocationButtonHandle
        saveLocalizationsBoxHandle
        methodDropdown
        methodPanel
        setLocalizerButtonHandle
        generateModelButtonHandle
        runLocalizerButtonHandle

        selectedMethod
        saveModelLocation
        saveLocalizationsLocation
        settingsPanel

        MOD
        LOC
    end
    methods
        function obj = localizePanel(wheresWhaledo, panelPosition, params)
            obj.wheresWhaledo = wheresWhaledo;
            % build panel to select array configuration
            obj.panelHandle = uipanel('Parent', obj.wheresWhaledo.fig, 'Title', '3. Localize', 'FontSize', 14, ...
                'Position', panelPosition, 'BackgroundColor', params.colors.background);

            buttonPosition(1) = panelPosition(3)/2 - 120;
            buttonPosition(2) = panelPosition(4) - 50;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.loadConfigButtonHandle = uibutton('push', 'Parent', obj.panelHandle, 'Text', 'load existing model/method', ...
                'Position', buttonPosition,'FontSize', 12, 'BackgroundColor', params.colors.items, ...
                'FontColor', params.colors.text, 'ButtonPushedFcn', @obj.loadConfig);

            obj.buildMethodDropdown

            % select save model text box:
            boxPosition(1) = 4;
            boxPosition(2) = obj.methodDropdown.Position(2) - 40;
            boxPosition(3) = obj.panelHandle.Position(3)-40;
            boxPosition(4) = 20;
            obj.saveModelBoxHandle = uieditfield(obj.panelHandle, 'text', ...
                'Placeholder', '[select model save location/file name...]', ...
                'Position', boxPosition, 'ValueChangedFcn', @obj.populateText);
            % select folder for wav file:
            buttonPosition = boxPosition;
            buttonPosition(1) = buttonPosition(1) + boxPosition(3) + 4;
            buttonPosition(3) = 20;
            [fpath, ~] = fileparts(mfilename('fullpath'));
            iconpath = fullfile(fpath, 'folder_icon.jpg');
            obj.selectModelLocationButtonHandle = uibutton(obj.panelHandle,'Icon', iconpath, 'IconAlignment', 'top', ...
                'Position', buttonPosition, 'Tooltip', 'Browse...', 'Text', '', 'Tag', 'wav',  ...
                'ButtonPushedFcn', @obj.selectModelSaveFile);
            obj.selectModelLocationButtonHandle.InnerPosition = obj.selectModelLocationButtonHandle.InnerPosition + [0, -2, 2, 2];

            % select save localizations text box:
            boxPosition(2) = boxPosition(2) - 24;
            obj.saveLocalizationsBoxHandle = uieditfield(obj.panelHandle, 'text', ...
                'Placeholder', '[select localizations file+name...]', ...
                'Position', boxPosition, 'ValueChangedFcn', @obj.populateText);
            % select folder for wav file:
            buttonPosition = boxPosition;
            buttonPosition(1) = buttonPosition(1) + boxPosition(3) + 4;
            buttonPosition(3) = 20;
            [fpath, ~] = fileparts(mfilename('fullpath'));
            iconpath = fullfile(fpath, 'folder_icon.jpg');
            obj.selectLocalizationsLocationButtonHandle = uibutton(obj.panelHandle,'Icon', iconpath, 'IconAlignment', 'top', ...
                'Position', buttonPosition, 'Tooltip', 'Browse...', 'Text', '', 'Tag', 'wav',  ...
                'ButtonPushedFcn', @obj.selectLocalizationSaveFile);
            obj.selectLocalizationsLocationButtonHandle.InnerPosition = obj.selectLocalizationsLocationButtonHandle.InnerPosition + [0, -2, 2, 2];

            % set localizer button:
            buttonPosition(1) = panelPosition(3)/2-120;
            buttonPosition(2) = obj.saveLocalizationsBoxHandle.Position(2) - 24;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.setLocalizerButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'set localizer', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.setLocalizer);

            % settings panel
            settingsPanelPosition(1) = boxPosition(1);
            settingsPanelPosition(2) = 10+24*4;
            settingsPanelPosition(3) = panelPosition(3)-8;
            settingsPanelPosition(4) = obj.setLocalizerButtonHandle.Position(2) - settingsPanelPosition(2) - 4;
            obj.settingsPanel = uipanel('Parent', obj.panelHandle, 'Position', settingsPanelPosition);

            % generate model button:
            buttonPosition(2) = 10+24;
            obj.generateModelButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'generate model', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.generateModel);

%             % save button
%             buttonPosition(2) = 10+24*1;
%             obj.saveConfigButtonHandle = uibutton('push', 'Parent', obj.panelHandle, 'Text', 'save localization configuration file', ...
%                 'Position', buttonPosition,'FontSize', 12, 'BackgroundColor', params.colors.items, ...
%                 'FontColor', params.colors.text, 'ButtonPushedFcn', @obj.saveConfig);

            % run localization button:
            buttonPosition(2) = 10;
            obj.runLocalizerButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'run localization', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.runLocalizer);
        end

        function buildMethodDropdown(obj)
            % get all methods available in +localization directory:
            d = dir(fullfile(obj.wheresWhaledo.params.wheresWhaledoPath, "./+localizers/*.m"));
            methodNames = {'--', d.name};

            ypos = obj.loadConfigButtonHandle.Position(2) - 40;
            xsize = obj.panelHandle.Position(3);
            lbl = uilabel("Parent", obj.panelHandle, "Text", "localization method: ",...
                "Position", [4, ypos, 110, 20], 'HorizontalAlignment', 'Right');
            obj.methodDropdown = uidropdown("Parent", obj.panelHandle, "Items", methodNames, ...
                "Position", [114, ypos, xsize-118, 20], "ValueChangedFcn", @obj.setMethod);
        end

        %% callback functions
        function loadConfig(obj, ~, ~)
            [file, location] = uigetfile('*.mat', 'Select localization config file');
            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled load\n')
            else
                % TO DO: set up everything with the parameters
            end
            figure(obj.panelHandle.Parent)
        end

        function selectModelSaveFile(obj, ~, ~)
            [file, location] = uiputfile('*.mat', 'Select model save location and file name', [obj.selectedMethod(1:end-2), '.mat']);

            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled save location select\n')
            else
                obj.saveModelLocation = fullfile(location, file);
                obj.saveModelBoxHandle.Value = obj.saveModelLocation;
            end
            figure(obj.panelHandle.Parent)
        end

        function selectLocalizationSaveFile(obj, ~, ~)
            [file, location] = uiputfile('*.mat', 'Select model save location and file name', [obj.selectedMethod(1:end-2), '.mat']);

            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled save location select\n')
            else
                obj.saveLocalizationsLocation = fullfile(location, file);
                obj.saveLocalizationsBoxHandle.Value = obj.saveLocalizationsLocation;
            end
            figure(obj.panelHandle.Parent)
        end

        function populateText(obj, ~, eventFile)
            obj.saveModelLocation = eventFile.Value;
        end

        function setMethod(obj, ~, eventData)
            obj.selectedMethod = eventData.Value;
        end


        function setLocalizer(obj, ~, ~)
            % erase any previous settings:
            delete(obj.settingsPanel.Children)
            locString = ['localizers.', obj.selectedMethod(1:end-2)];
            obj.localizer = feval(locString, obj.wheresWhaledo);
            G = utils.buildUserParamsGrid(obj.settingsPanel, obj.localizer);
        end

        function generateModel(obj, ~, ~)
            obj.localizer.userParams = utils.getUserParamsFromGrid(obj.settingsPanel.Children);
            if isempty(obj.saveModelLocation)
                obj.saveModelLocation = [pwd, '\localizationModel.mat'];
            end
            obj.localizer.prepare(obj.saveModelLocation)
        end

        function runLocalizer(obj, ~, ~)
            obj.localizer.run
        end
    end
end