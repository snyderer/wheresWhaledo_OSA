function result = loadParams(filename)
    % Initialize an empty structure for temporary storage
    tempStruct = struct();
    
    % Open the file for reading
    fid = fopen(filename, 'r');
    
    % Check if the file was opened successfully
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    % Initialize the structure name variable
    structName = '';
    
    % Read lines from the file and dynamically assign values
    while ~feof(fid)
        tline = strtrim(fgets(fid));
        if ~isempty(tline)
            % Split the line by '=' to get the field assignment
            parts = strsplit(tline, '=');
            if length(parts) == 2
                % Extract the variable part (before '=')
                varPart = strtrim(parts{1});
                
                % Extract the structure name if not already determined
                if isempty(structName)
                    dotIndex = strfind(varPart, '.');
                    if ~isempty(dotIndex)
                        structName = varPart(1:dotIndex(1)-1);
                    else
                        error('Invalid format: expected structure name in the file');
                    end
                end
                
                % Replace the structure name with 'tempStruct' for dynamic assignment
                dynamicLine = strrep(tline, structName, 'tempStruct');
                
                % Evaluate the dynamic assignment line
                eval(dynamicLine);
            end
        end
    end
    
    % Close the file
    fclose(fid);
    
    % Extract the dynamically created structure from tempStruct
    result = tempStruct.(structName);
end