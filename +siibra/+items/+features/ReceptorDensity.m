classdef ReceptorDensity
    %REZEPTORDENSITY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Region siibra.items.Region
        Id string
        Description string
        Name string
        Fingerprint string
        Unit string
    end
    
    methods
        function obj = ReceptorDensity(region, receptorJson)
            obj.Region = region;
            obj.Id = receptorJson.id;
            obj.Description = receptorJson.description;
            obj.Name = receptorJson.name;
            obj.Unit = "fmol/mg";
        end
        
        function fingerprints = get.Fingerprint(obj)
            fingerprintJson = siibra.internal.API.doWebreadWithLongTimeout( ...
                siibra.internal.API.tabularFeature( ...
                obj.Region, ...
                obj.Id));
            fingerprintStruct = fingerprintJson.data.fingerprints;
            receptors = fieldnames(fingerprintStruct);
            means = arrayfun(@(i) fingerprintStruct.(receptors{i}).mean, 1:numel(receptors));
            stds = arrayfun(@(i) fingerprintStruct.(receptors{i}).std, 1:numel(receptors));
            fingerprints = table(means.', stds.', 'VariableNames', ["Mean", "Std"], 'RowNames', receptors);
        end
    end
end

