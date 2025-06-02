function params = getUserParamsFromGrid(G)
% extracts params from a userParamsGrid built with buildUserParamsGrid.m
numParams = numel(G.RowHeight)-1; % number of unique params

paramNames = cell(numParams, 1);
paramVals = cell(numParams, 1);

for i = 1:numel(G.Children)
    % determine row and column of this child:
    row = G.Children(i).Layout.Row;
    col = G.Children(i).Layout.Column;

    if row==1 % title row, skip
        continue
    end
    
    switch col
        case 1
            paramNames{row-1} = G.Children(i).Text(1:end-2);
        case 2
            paramVals{row-1} = G.Children(i).Value;
    end
end

% iterate through each param and save it in params struct:
params = struct;
for i = 1:numParams
    params.(paramNames{i}) = paramVals{i};
end
end