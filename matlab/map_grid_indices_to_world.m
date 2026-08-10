function worldXY = map_grid_indices_to_world(map, rows, cols)
%MAP_GRID_INDICES_TO_WORLD  Matrix [row,col] from occupancyMatrix -> [x,y] world.
%
%   Uses occupancyMap grid2world so Y axis matches Navigation Toolbox convention.

    if isempty(rows)
        worldXY = zeros(0, 2);
        return;
    end

    gridIdx = [cols(:), rows(:)];
    worldXY = grid2world(map, gridIdx);
end
