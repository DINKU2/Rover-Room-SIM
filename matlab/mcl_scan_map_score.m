function score = mcl_scan_map_score(map, ls, pose)
%MCL_SCAN_MAP_SCORE  Strict 0..1 scan-to-wall match fraction.

    score = mcl_scan_map_match(map, ls, pose).score;
end
