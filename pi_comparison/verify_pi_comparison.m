function evidence=verify_pi_comparison()
here=fileparts(mfilename('fullpath'));S=jsondecode(fileread(fullfile(here,'comparison_summary.json')));if ~iscell(S),S=num2cell(S);end
frozen=load(fullfile(here,'pi_design.mat'),'designs');
evidence=cell(numel(S),1);
for k=1:numel(S)
 id=S{k}.id;folder=fullfile(here,'results',id);n=fullfile(folder,['CMP_' id '_NN.slx']);p=fullfile(folder,['CMP_' id '_PI.slx']);
 tpc_assert_topology(n,p);[ns,nt]=signature(n);[ps,pt]=signature(p);assert(isequal(ns,ps),'Physical parameter mismatch: %s',id);assert(isequal(nt,pt),'Timing or duty limit mismatch: %s',id);
 N=load(fullfile(folder,'NN.mat'),'tc','cfg');P=load(fullfile(folder,'PI.mat'),'tc','cfg','p');assert(isequal(size(N.tc),size(P.tc))&&max(abs(N.tc-P.tc))<1e-10);
 settings=P.p;if ~iscell(settings),settings={settings};end
 for j=1:numel(settings)
  z=settings{j};ix=find(cellfun(@(x)strcmp(x.id,z.id),frozen.designs),1);assert(~isempty(ix));expected=frozen.designs{ix};
  for key={'KpI','KiI','KpV','KiV','direction','uMin','uMax','Ts'},assert(isequal(z.(key{1}),expected.(key{1})),'PI design and cached run disagree; archive old results and rerun.');end
 end
 networkCount=verifyNetwork(n,N.cfg,here);
 evidence{k}=struct('id',id,'physicalBlocks',numel(ns),'physicalParametersEqual',true,'topologyEqual',true,'timingAndDutyLimitsEqual',true,'cycleMeanTimeGridEqual',true,'freshNNAndPI',true,'PIParametersMatchFrozenDesign',true,'embeddedNetworksEqualFormalMAT',true,'networkBlocks',networkCount,'source','independent clones of one saved baseline model');
 fprintf('PI_FAIRNESS_VERIFIED %s\n',id);
end
fid=fopen(fullfile(here,'fairness_verification.json'),'w');fprintf(fid,'%s',jsonencode(evidence,PrettyPrint=true));fclose(fid);
end
function count=verifyNetwork(file,cfg,here)
base=fullfile(fileparts(here),'48_72_120_C220_16_8');R=jsondecode(fileread(fullfile(base,'config','target_cases.json')));if ~iscell(R),R=num2cell(R);end
h=load_system(file);mdl=get_param(h,'Name');cleanup=onCleanup(@()close_system(mdl,0));
blocks=find_system(mdl,'RegExp','on','Name','^TPC_NN(_[0-9]+)?$');count=numel(blocks);assert(count>=1);
for k=1:count
 name=get_param(blocks{k},'Name');head=[];
 if isfield(cfg,'mapping'),ix=str2double(extractAfter(name,'TPC_NN_'));id=cfg.mapping(ix).mode;head=cfg.mapping(ix).head;else,id=cfg.id;end
 j=find(cellfun(@(x)strcmp(x.id,id),R),1);assert(~isempty(j));T=load(fullfile(base,R{j}.codeRel,'models','net_48_72_120.mat'),'net');net=T.net;
 expected={net.W1,net.W2,net.W3};bias={net.b1,net.b2,net.b3};if ~isempty(head),expected{3}=expected{3}(head,:);bias{3}=bias{3}(head);end
 assert(isequal(size(expected{1}),[16 4])&&isequal(size(expected{2}),[8 16]));
 for layer=1:3
  actual=str2num(get_param(sprintf('%s/Layer%d_Weights',blocks{k},layer),'Gain')); %#ok<ST2NM>
  b=str2num(get_param(sprintf('%s/Layer%d_Bias',blocks{k},layer),'Bias')); %#ok<ST2NM>
  assert(isequal(actual,expected{layer})&&isequal(b,bias{layer}),'Embedded NN differs from formal MAT.');
 end
 actual=str2num(get_param([blocks{k} '/InputScale'],'Gain'));b=str2num(get_param([blocks{k} '/InputShift'],'Bias')); %#ok<ST2NM>
 assert(isequal(actual,diag(net.inputGain))&&isequal(b,net.inputShift));
end
end
function [s,timing]=signature(file)
h=load_system(file);m=get_param(h,'Name');cleanup=onCleanup(@()close_system(m,0));
B=find_system(m,'SearchDepth',1,'Type','Block');names=cellfun(@(b)get_param(b,'Name'),B,'UniformOutput',false);[~,order]=sort(names);s={};
for k=order(:)'
 b=B{k};n=get_param(b,'Name');if strcmp(b,m)||startsWith(n,'TPC_'),continue;end
 q={n,get_param(b,'BlockType'),get_param(b,'MaskType'),get_param(b,'MaskValues')};
 if strcmp(get_param(b,'BlockType'),'Step'),q=[q,{get_param(b,'Time'),get_param(b,'Before'),get_param(b,'After')}];end
 s{end+1}=q;
end
timing={get_param(m,'StopTime'),get_param(m,'Solver'),get_param(m,'MaxStep'),get_param(m,'RelTol')};
B=find_system(m,'RegExp','on','Name','^TPC_FeedbackDelay$|^TPC_DutyLimit_[0-9]+$');
for k=1:numel(B)
 if strcmp(get_param(B{k},'BlockType'),'Saturation'),timing{end+1}={get_param(B{k},'Name'),get_param(B{k},'LowerLimit'),get_param(B{k},'UpperLimit')};
 else,timing{end+1}={get_param(B{k},'Name'),get_param(B{k},'SampleTime')};end
end
end
