classdef brushGUI < handle
    % general brushing object for plotting, brushing, and labeling data
    % h = brushGUI(x, y, params); plots data x and y as scatter plot. 
    % Optional run configurations are:
    %     a) y is NplotsxNdata array, where Nplots represents the number of
    %        unique plots and Ndata represents the number of datapoints. 
    %          a.1) if x is 1xNdata, the x data are assumed to be linked and
    %             changes made to any datapoint will be applied to all plots
    %             corresponding that that value of x. This can be turned on/off
    %             using h.params.linkXdata = true/false.
    %          a.2) if x is NplotsxNdata, each axis is assumed to be
    %             independent, and changes will not apply to all points.
    %     b) x and y are cells x{Nplots} and y{Plots}. Each array within
    %        the cell can have its own number of datapoints. If y{n} is
    %        MxN, then x{n} must be either 1xN or MxN.
    % h = brushGUI(x, y, cdata, params) plots data as imagesc where cdata
    %     is a cell array of all plots
    % Optional run configurations are:
    %     a) x is 1xNX and y is 1xNY. cdata{nplot} must be NXxNY.
    %     b) x and y are cell with the same number of arrays as cdata. 
    %        x{nplot} is 1xNX, y{nplot} is 1xNY, and cdata{nplot} must be NXxNY.
    
    properties
        data
        params
        axesHandles
    end

    methods
        function obj = brushGUI(x, y, c, params)
            if nargin==3
                params = c;
                if ~isfield(params, 'plotType')
                    params.plotType = 'scatter';
                end
            elseif nargin==4
                if ~isfield(params, 'plotType')
                    params.plotType = 'imagesc';
                end
            end
            obj.params = params;
            
            % construct data object:
            switch obj.params.plotType
                case 'scatter'
                    obj.setScatterData(x, y);
                case 'imagesc'
                    obj.setImagescData;
            end
        end

        %% setting data and generating plots
        function setScatterData(obj, x, y)
            
            if iscell(y) && iscell(x)
                obj.params.maxNumPlots = numel(y);
                obj.data.x = x;
                obj.data.y = y;
                if ~isfield(obj.params, 'linkXdata')
                    obj.params.linkXdata = false;
                end
            elseif iscell(y) && ~iscell(x)
                obj.params.maxNumPlots = numel(y);
                obj.data.x = cell(1, obj.params.maxNumPlots);
                obj.data.x(:) = {x};
                obj.data.y = y;
                if ~isfield(obj.params, 'linkXdata')
                    obj.params.linkXdata = false;
                end
            elseif ~iscell(y) && size(x, 1) =
                for ndata = 1:obj.params.maxNumPlots
                    obj.data.x{ndata} = x;
                    obj.data.y{ndata} = y(:, ndata);
                end
            end

        end

        function setImagescData(obj)

        end
        %%
    end
end