load_system("simulink");
p = get_param("simulink/Signal Routing/Vector Concatenate", "ObjectParameters");
fn = fieldnames(p);
for i = 1:numel(fn)
    try
        v = p.(fn{i}).DefaultValue;
        fprintf("%s default=%s\n", fn{i}, string(v));
    catch
    end
end
