function debug_livemap_lines()
    load_system('/home/dinuk/Desktop/project/Rover-Room-SIM/simulink/rover_ros_io.slx');
    blocks = {'ScanToMap', 'OdomExtract', 'MapInputs', 'LiveMap'};
    for i = 1:numel(blocks)
        p = ['rover_ros_io/' blocks{i}];
        try
            ph = get_param(p, 'PortHandles');
            fprintf('== %s ==\n', blocks{i});
            for k = 1:numel(ph.Inport)
                lh = get_param(ph.Inport(k), 'Line');
                if lh > 0
                    fprintf('  In %d from %s:%d\n', k, ...
                        get_param(get_param(lh, 'SrcBlockHandle'), 'Name'), ...
                        get_param(lh, 'SrcPortHandle'));
                end
            end
            for k = 1:numel(ph.Outport)
                lh = get_param(ph.Outport(k), 'Line');
                if lh > 0
                    dsts = get_param(lh, 'DstBlockHandle');
                    for d = 1:numel(dsts)
                        if dsts(d) > 0
                            fprintf('  Out %d to %s\n', k, get_param(dsts(d), 'Name'));
                        end
                    end
                end
            end
        catch ME
            fprintf('== %s missing: %s\n', blocks{i}, ME.message);
        end
    end
    bdclose('rover_ros_io');
end
