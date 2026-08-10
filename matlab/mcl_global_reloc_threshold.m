function thresh = mcl_global_reloc_threshold()
%MCL_GLOBAL_RELOC_THRESHOLD  Fit score below which Phase-1 global search runs.
%
%   Default 0.70 (70%). Override:
%     setenv('MCL_GLOBAL_RELOC_THRESHOLD','0.60')

    thresh = 0.70;
    raw = getenv('MCL_GLOBAL_RELOC_THRESHOLD');
    if isempty(raw)
        return;
    end
    v = str2double(raw);
    if isfinite(v) && v > 0 && v <= 1
        thresh = v;
    end
end
