function atlas = atlas(atlas_name)
% Construct atlas by name
%   Detailed explanation goes here
    atlases = siibra.internal.initAtlases(false);
    atlas = atlases(siibra.internal.fuzzyMatching(atlas_name, {atlases.name}));
end


