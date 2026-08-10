function [rows, cols, inBounds] = map_world_to_grid_indices(map, wx, wy)
%MAP_WORLD_TO_GRID_INDICES  World [x,y] -> matrix [row,col] for occupancyMatrix.

    n = numel(wx);
    rows = zeros(n, 1);
    cols = zeros(n, 1);
    inBounds = false(n, 1);

    if n == 0
        return;
    end

    gridIdx = world2grid(map, [wx(:), wy(:)]);
    cols = round(gridIdx(:, 1));
    rows = round(gridIdx(:, 2));

    prob = occupancyMatrix(map);
    nRows = size(prob, 1);
    nCols = size(prob, 2);
    inBounds = rows >= 1 & rows <= nRows & cols >= 1 & cols <= nCols;
end
