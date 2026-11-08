% Read-only inventory of top-level PID blocks in the original PI directory.
here=fileparts(mfilename('fullpath'));
source=fullfile(fileparts(fileparts(fileparts(here))), ...
    'ICPRE会议论文资料+修改版','matlab闭环仿真','PI闭环');
files=dir(fullfile(source,'**','*.slx'));
rows=cell(0,9);
for k=1:numel(files)
    full=fullfile(files(k).folder,files(k).name);
    rel=erase(full,[source filesep]);
    [~,mdl]=fileparts(full);
    try
        load_system(full);
        blocks=find_system(mdl,'SearchDepth',1,'Type','Block');
        names=cellfun(@(b)get_param(b,'Name'),blocks,'UniformOutput',false);
        pid=blocks(contains(names,'PID Controller'));
        if isempty(pid)
            rows(end+1,:)={rel,'',get_param(mdl,'StopTime'),'','','','','',''}; %#ok<AGROW>
        else
            for j=1:numel(pid)
                b=pid{j};
                p=get_param(b,'ObjectParameters');
                values=cell(1,6);
                props={'Controller','P','I','D','N','TimeDomain'};
                for n=1:6
                    if isfield(p,props{n})
                        values{n}=char(get_param(b,props{n}));
                    else
                        values{n}='';
                    end
                end
                rows(end+1,:)=[{rel,get_param(b,'Name'), ...
                    get_param(mdl,'StopTime')},values]; %#ok<AGROW>
            end
        end
        bdclose(mdl);
    catch ME
        if bdIsLoaded(mdl),bdclose(mdl);end
        rows(end+1,:)={rel,['ERROR: ' ME.message],'','','','','','',''}; %#ok<AGROW>
    end
end
t=cell2table(rows,'VariableNames', ...
    {'file','block','stop_s','controller','P','I','D','N','time_domain'});
writetable(t,fullfile(here,'原PI目录控制器参数核对.csv'));
disp(t);
