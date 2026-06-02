function inspect_rover_ros_io()
    slxPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'simulink', 'rover_ros_io.slx');
    load_system(slxPath);
    blks = find_system('rover_ros_io', 'SearchDepth', 1, 'Type', 'block');
    for i = 1:numel(blks)
        b = blks{i};
        fprintf('--- %s (%s) ---\n', get_param(b, 'Name'), get_param(b, 'BlockType'));
        ph = get_param(b, 'PortHandles');
        if isfield(ph, 'Inport')
            fprintf('  Inports: %d\n', numel(ph.Inport));
        end
        if isfield(ph, 'Outport')
            fprintf('  Outports: %d\n', numel(ph.Outport));
        end
        if strcmp(get_param(b, 'BlockType'), 'SubSystem')
            outports = find_system(b, 'SearchDepth', 1, 'BlockType', 'Outport');
            for j = 1:numel(outports)
                fprintf('    Out %s\n', get_param(outports{j}, 'Name'));
            end
        end
        if strcmp(get_param(b, 'BlockType'), 'InterpretedFcn')
            fprintf('  MATLABFcn: %s\n', get_param(b, 'MATLABFcn'));
        end
    end
    bdclose('rover_ros_io');
end
