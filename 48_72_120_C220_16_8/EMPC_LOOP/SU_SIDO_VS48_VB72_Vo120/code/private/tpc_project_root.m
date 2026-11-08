function root=tpc_project_root()
root=fileparts(mfilename('fullpath'));
while ~isfile(fullfile(root,'run_all_modes.m')) || ~isfolder(fullfile(root,'EMPC_LOOP'))
 parent=fileparts(root);assert(~strcmp(parent,root),'Project root not found.');root=parent;
end
end
