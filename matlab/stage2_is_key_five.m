function tf = stage2_is_key_five(evt)
%STAGE2_IS_KEY_FIVE  True for keyboard or numpad 5.

    tf = false;
    if isfield(evt, 'Key') && ~isempty(evt.Key) && strcmp(evt.Key, '5')
        tf = true;
        return;
    end
    if isfield(evt, 'Character') && ~isempty(evt.Character) && evt.Character == '5'
        tf = true;
    end
end
