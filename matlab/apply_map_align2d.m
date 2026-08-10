function ptsOut = apply_map_align2d(ptsIn, R2d, t2d)
%APPLY_MAP_ALIGN2D  Apply 2D rigid transform to Nx2 points.

    t = t2d(:);
    ptsOut = (R2d * ptsIn' + t)';
end
