function [cfg,initialization]=tpc_load_case(codeDir)
% Read this case's editable MATLAB parameters, without modifying any artifact.
run(fullfile(codeDir,'parameters.m'));
end
