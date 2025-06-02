classdef detectorPanel < handle
    properties
        wheresWhaledo
        panelHandle         % handle for detector panel within Where's Whaledo interface
        loadDetectionBtn    % handle to select existing detection file
        
        speciesListHandle       % handle of list of species/source types
        detectorListHandle      % handle of list of detectors (displays only detectors for currently selected species)
        wavFileBoxHandle        % handle of box for inputing wav file
        selectWavFileButtonHandle
        saveFileBoxHandle
        saveFileButtonHandle
        setDetectorButtonHandle
        runDetectorButtonHandle
        runBrushTDOAButtonHandle
        runOnDirectoryCheckbox

        detectorTree    % struct containing all available detectors
        selectedSpecies
        selectedDetector
        wavFile
        saveFile

        detector        % detector object
        settingsPanel   
        DET    
    end
    methods
        function obj = detectorPanel(wheresWhaledo, panelPosition, params)
            obj.wheresWhaledo = wheresWhaledo;
            obj.panelHandle = uipanel('Parent', obj.wheresWhaledo.fig, 'Title', '2. Select and run detector', 'FontSize', 14, ...
                'Position', panelPosition,  'BackgroundColor', params.colors.background);

            % load detection file push button:
            buttonPosition(1) = panelPosition(3)/2 - 120;
            buttonPosition(2) = panelPosition(4) - 50;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.loadDetectionBtn = uibutton('push', 'Parent', obj.panelHandle, 'Text', 'load existing detection file', ...
                'Position', buttonPosition,'FontSize', 12, 'BackgroundColor', params.colors.items, ...
                'FontColor', params.colors.text, 'ButtonPushedFcn', @obj.loadDetFile);

            % Get list of species and detectors by scanning ./+detectors directory:
            dspecies = dir(fullfile(params.wheresWhaledoPath, '+detectors\+*')); % determine which species have folders
            for nspec = 1:numel(dspecies)
                obj.detectorTree(nspec).speciesName = dspecies(nspec).name(2:end);
                ddetectors = dir(fullfile(dspecies(nspec).folder, dspecies(nspec).name, '/*.m'));
                detectors = cell(numel(ddetectors), 1);
                for ndet = 1:numel(ddetectors)
                    detectors{ndet} = ddetectors(ndet).name;
                end
                obj.detectorTree(nspec).detectors = detectors;
            end

            % make species listbox
            uilabel(obj.panelHandle, 'Text', 'select species/source:', 'HorizontalAlignment', 'center', ...
                'Position', [panelPosition(3)/4 - 60, panelPosition(4)-80, 120, 20]);
            spListboxPosition(1) = 4;
            spListboxPosition(2) = panelPosition(4) - 250;
            spListboxPosition(3) = panelPosition(3)/2-6;
            spListboxPosition(4) = 170;
            obj.speciesListHandle = uilistbox(obj.panelHandle, 'Items', {obj.detectorTree.speciesName}, 'Position', spListboxPosition, ...
                'ValueChangedFcn', @obj.speciesSelected);
            obj.selectedSpecies = obj.speciesListHandle.Value;

            % make detector listbox
            uilabel(obj.panelHandle, 'Text', 'select detector:', 'HorizontalAlignment', 'center', ...
                'Position', [3*panelPosition(3)/4 - 60, panelPosition(4)-80, 120, 20]);
            detListboxPosition = spListboxPosition;
            detListboxPosition(1) = panelPosition(3)/2+2;
            obj.detectorListHandle = uilistbox(obj.panelHandle, 'Items', obj.detectorTree(1).detectors, 'Position', detListboxPosition, ...
                'ValueChangedFcn', @obj.detectorSelected);
            obj.selectedDetector = obj.detectorListHandle.Value;

            % select input wav file text box:
            boxPosition(1) = 4;
            boxPosition(2) = obj.detectorListHandle.Position(2) - 24;
            boxPosition(3) = 240;
            boxPosition(4) = 20;
            obj.wavFileBoxHandle = uieditfield(obj.panelHandle, 'text', ...
                'Placeholder', '[enter path to wav file(s)...]', ...
                'Position', boxPosition, 'ValueChangedFcn', @obj.populateText);
            % select folder for wav file:
            buttonPosition = boxPosition;
            buttonPosition(1) = buttonPosition(1) + boxPosition(3) + 4;
            buttonPosition(3) = 20;
            [fpath, ~] = fileparts(mfilename('fullpath'));
            iconpath = fullfile(fpath, 'folder_icon.jpg');
            obj.selectWavFileButtonHandle = uibutton(obj.panelHandle,'Icon', iconpath, 'IconAlignment', 'top', ...
                'Position', buttonPosition, 'Tooltip', 'Browse...', 'Text', '', 'Tag', 'wav',  ...
                'ButtonPushedFcn', @obj.selectWavFile);
            obj.selectWavFileButtonHandle.InnerPosition = obj.selectWavFileButtonHandle.InnerPosition + [0, -2, 2, 2];
            
            % checkbox to run on full directory:
            checkboxPosition(1) = buttonPosition(1) + buttonPosition(3) + 4;
            checkboxPosition(2) = boxPosition(2);
            checkboxPosition(3) = panelPosition(3) - checkboxPosition(1) - 4;
            checkboxPosition(4) = boxPosition(4);
            obj.runOnDirectoryCheckbox = uicheckbox("Parent", obj.panelHandle, ...
                "Text", "full directory", "Position", checkboxPosition, "Value", 1);

            % select save location
            boxPosition(2) = obj.selectWavFileButtonHandle.Position(2) - 24;
            obj.saveFileBoxHandle = uieditfield(obj.panelHandle, 'text', ...
                'Placeholder', '[enter save location/filename...]', ...
                'Position', boxPosition);
            buttonPosition = boxPosition;
            buttonPosition(1) = buttonPosition(1) + boxPosition(3) + 4;
            buttonPosition(3) = 20;
            obj.saveFileButtonHandle = uibutton(obj.panelHandle,'Icon', iconpath, 'IconAlignment', 'top', ...
                'Position', buttonPosition, 'Tooltip', 'Browse...', 'Text', '', 'Tag', 'save',...
                'ButtonPushedFcn', @obj.selectSaveFile);
            obj.saveFileButtonHandle.InnerPosition = obj.saveFileButtonHandle.InnerPosition + [0, -1, 2, 2];

            % set detector button:
            buttonPosition(1) = panelPosition(3)/2-120;
            buttonPosition(2) = obj.saveFileBoxHandle.Position(2) - 24;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.setDetectorButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'set detector', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.setDetector);

            % initialize settings table
            settingsPanelPosition(1) = spListboxPosition(1);
            settingsPanelPosition(2) = 52;
            settingsPanelPosition(3) = panelPosition(3)-8;
            settingsPanelPosition(4) = obj.setDetectorButtonHandle.Position(2) - settingsPanelPosition(2) - 4;
            obj.settingsPanel = uipanel('Parent', obj.panelHandle, 'Position', settingsPanelPosition);

            % run detector button:
            buttonPosition(1) = panelPosition(3)/2-120;
            buttonPosition(2) = 28;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.runDetectorButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'run detector', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.runDetector);

            % run brush TDOA button:
            buttonPosition(1) = panelPosition(3)/2-120;
            buttonPosition(2) = 4;
            buttonPosition(3) = 240;
            buttonPosition(4) = 20;
            obj.runBrushTDOAButtonHandle = uibutton(obj.panelHandle, 'BackgroundColor', params.colors.items, ...
                'Text', 'run BrushTDOA', 'Position', buttonPosition, 'ButtonPushedFcn', @obj.runBrushTDOA);
        end

        %% Callback functions
        function speciesSelected(obj, ~, ~)
            obj.selectedSpecies = obj.speciesListHandle.Value;
            speciesNumber = find(strcmp({obj.detectorTree.speciesName}, obj.selectedSpecies));
            set(obj.detectorListHandle, 'Items', obj.detectorTree(speciesNumber).detectors)
            obj.detectorSelected
        end

        function detectorSelected(obj, ~, ~)
            obj.selectedDetector = obj.detectorListHandle.Value;
        end

        function selectWavFile(obj, ~, ~)
            [file, location] = uigetfile('*wav', 'Select wav file');
            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled wav select\n')
            else
                obj.wavFile = fullfile(location, file);
                obj.wavFileBoxHandle.Value = obj.wavFile;
            end
            figure(obj.panelHandle.Parent)
        end

        function selectSaveFile(obj, ~, ~)
            [file, location] = uiputfile('*.mat', 'Select save location and file name', [obj.selectedSpecies, '.mat']);
            
            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled save location select\n')
            else
                obj.saveFile = fullfile(location, file);
                obj.saveFileBoxHandle.Value = obj.saveFile;
            end
            figure(obj.panelHandle.Parent)
        end

        function populateText(obj, h, eventFile)
            switch h.Tag
                case 'wav'
                    obj.wavFile = eventFile.Value;
                case 'save'
                    obj.saveFile = eventFile.Value;
            end
        end

        function loadDetFile(obj, ~, ~)
            [file, location] = uigetfile('*.mat', 'Select detection file');
            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled load\n')
            else
                tmp = load(fullfile(location, file));
                if isfield(tmp, 'DET')
                    obj.DET = tmp.DET;
                else
                    fprintf('\nError: detection file does not contain DET table\n')
                end
            end
            figure(obj.panelHandle.Parent)
        end

        function saveDetFile(obj, ~, ~)
            
            if isempty(obj.saveFile)
                [file, location] = uiputfile('*.mat', 'Select save location and file name', 'detections.mat');
            else
                [file, location] = fileparts(obj.saveFile);
            end
            if isequal(file,0) || isequal(location,0)
                % no file selected
                fprintf('\ncanceled save\n')
            else
                DET = obj.DET.Data;
                save(fullfile(location, [file, '.mat']), 'DET');
            end
            figure(obj.panelHandle.Parent)
        end

        function runBrushSpect(obj, ~, ~)
            % TO DO
        end

        function runBrushTDOA(obj, ~, ~)
            if isempty(obj.DET)
                fprintf('no detection file -- run detector or select detection file')
                return
            end
            brsh = gui.brushTDOA(obj.DET, [], obj.saveFile);
            
            obj.DET = brsh.data;
        end

        function setDetector(obj, ~, ~)
            % erase any previous settings: 
            delete(obj.settingsPanel.Children)
            detString = ['detectors.', obj.selectedSpecies, '.', obj.selectedDetector(1:end-2)];
            obj.detector = feval(detString, obj.wheresWhaledo);
            G = utils.buildUserParamsGrid(obj.settingsPanel, obj.detector);
        end
        function runDetector(obj, ~, ~)
            obj.detector.userParams = utils.getUserParamsFromGrid(obj.settingsPanel.Children);
            
            if obj.runOnDirectoryCheckbox.Value
                [wavpath, ~] = fileparts(obj.wavFile);
                d = dir(fullfile(wavpath, '*.wav'));
                obj.DET = obj.detector.run(fullfile(d(1).folder, d(1).name));
                for i = 2:numel(d)
                    det = obj.detector.run(fullfile(d(i).folder, d(i).name));
                    obj.DET = [obj.DET; det];
                end
            else
                obj.DET = obj.detector.run(obj.wavFile);
            end
            DET = obj.DET;
            save(obj.saveFile, 'DET')
        end
    end
end