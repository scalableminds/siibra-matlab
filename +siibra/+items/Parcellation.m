classdef Parcellation < handle
    %PARCELLATION The parcellation belongs to a certain atlas and holds the
    %RegionTree and the available spaces.
    
    properties
        Id (1, 1) string
        Name (1, 1) string
        Atlas (1, :) siibra.items.Atlas
        Modality (1, 1) string
        Description (1, 1) string
        RegionTree (1, 1) digraph
        Regions (1, :) siibra.items.Region
        Spaces (1, :) siibra.items.Space
    end

    methods
        function parcellation = Parcellation(parcellationJson, atlas)
            parcellation.Id = parcellationJson.x_id;
            parcellation.Name = parcellationJson.name;
            parcellation.Atlas = atlas;
            
            if isempty(parcellationJson.modality)
                parcellation.Modality = "";
            else
                parcellation.Modality = parcellationJson.modality;
            end

            spaceIds = arrayfun(@(atlasVersion) atlasVersion.coordinateSpace, parcellationJson.brainAtlasVersions);
            spaces = arrayfun(@(spaceId) atlas.Spaces([atlas.Spaces.Id] == spaceId.x_id), spaceIds);
            if isempty(spaces)
                parcellation.Spaces = siibra.items.Space.empty();
            else
                parcellation.Spaces = spaces;
            end
            
            regionsJson = siibra.internal.API.regions(parcellation.Id);
            function result = getSrc(regionJson)
                if isempty(regionJson.hasParent)
                    result = regionJson.x_id;
                else
                    result = regionJson.hasParent.x_id;
                end

            end
            % the api returns the same regions multiple times. so we filter
            % them here.
            [~, uniqueRegionIndices, ~] = unique({regionsJson.x_id});
            parcellation.Regions = arrayfun(@(regionJson) siibra.items.Region(regionJson.x_id, regionJson.name, parcellation), regionsJson(uniqueRegionIndices));
            srcIds = arrayfun(@(regionJson) getSrc(regionJson), regionsJson(uniqueRegionIndices), "UniformOutput",false);
            regionIds = [parcellation.Regions.Id];
            src = arrayfun(@(srcId) find(regionIds == srcId), srcIds);
            dst = 1:numel(src);

            nodeTable = table([parcellation.Regions.Id].', [parcellation.Regions.Name].', parcellation.Regions.', 'VariableNames', ["Name", "RegionName", "Region"]);
            % store graph
            parcellation.RegionTree = digraph(src, dst, zeros(length(src), 1),  nodeTable);
        end

        function map = parcellationMap(obj, space)
            map = siibra.items.maps.ParcellationMap(obj, space);
        end
       
        function regionNames = findRegion(obj, regionNameQuery)
            regionNames = obj.RegionTree.Nodes(contains(obj.RegionTree.Nodes.RegionName, regionNameQuery), 2);
        end
        function region = decodeRegion(obj, regionNameQuery)
            index = siibra.internal.fuzzyMatching(regionNameQuery, [obj.RegionTree.Nodes.RegionName]);
            region = obj.RegionTree.Nodes.Region(index);
        end
        function region = getRegion(obj, regionNameQuery)
            nodeId = obj.RegionTree.findnode(regionNameQuery);
            region = obj.RegionTree.Nodes.Region(nodeId);
        end
        function children = getChildRegions(obj, region)
            nodeId = obj.RegionTree.findnode(region.Id);
            childrenIds = obj.RegionTree.successors(nodeId);
            children = obj.RegionTree.Nodes.Region(childrenIds);
        end
        function parentRegion = getParentRegion(obj, region)
            nodeId = obj.RegionTree.findnode(region.Id);
            parents = obj.RegionTree.predecessors(nodeId);
            assert(length(parents) == 1, "Expect just one parent in a tree structure");
            parentId = parents(1);
            parentRegion = obj.RegionTree.Nodes.Region(parentId);
        end

        function features = getAllFeatures(obj)
            cached_file_name = siibra.internal.cache(obj.Name + ".mat", "parcellation_features");
            if ~isfile(cached_file_name)
                features = siibra.internal.API.featuresForParcellation(obj.Atlas.Id, obj.Id);
                save(cached_file_name, 'features');
            else
                load(cached_file_name, 'features')
            end

        end

        function streamlineCounts = getStreamlineCounts(obj)
            allFeatures = obj.getAllFeatures();
            streamlineCountIdx = arrayfun(@(e) strcmp(e.x_type,'siibra/features/connectivity/streamlineCounts'), allFeatures);
            streamlineCounts = arrayfun(@(json) siibra.items.features.StreamlineCounts(obj, json), allFeatures(streamlineCountIdx));
        end
    end
    

    methods (Static)
        function tree = createParcellationTree(parcellation, regions)
            root.name = parcellation.Name;
            root.children = regions;
            [source, target, region] = siibra.items.Parcellation.traverseTree(parcellation, root, string.empty, string.empty, siibra.items.Region.empty);
            % append root node
            nodes = target;
            nodes(length(nodes) + 1) = root.name;
            region(length(region) + 1) = siibra.items.Region(root.name, parcellation, []);
            % make nodes unique
            [uniqueNodes, uniqueIndices, ~] = unique(nodes);
            nodeTable = table(uniqueNodes.', region(uniqueIndices).', 'VariableNames', ["Name", "Region"]);
            tree = digraph(source, target, zeros(length(target), 1),  nodeTable);
        end

        function [source, target, regions] = traverseTree(parcellation, root, source, target, regions)
            % Parses the parcellation tree.
            % Recursively calls itself to parse the children of the current
            % root.
            % Creates a region for each node in the parcellation tree.

            for childNum = 1:numel(root.children)
                child = root.children(childNum);
                source(length(source) + 1) = root.name;
                target(length(target) + 1) = child.name;
                regions(length(regions) + 1) = siibra.items.Region(child.name, parcellation, child.x_dataset_specs);
                [source, target, regions] = siibra.items.Parcellation.traverseTree(parcellation, child, source, target, regions);
            end
        end
    end
end